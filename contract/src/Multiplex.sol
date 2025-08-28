// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

import { Base64 } from "solady/utils/Base64.sol";
import { Lifebuoy } from "solady/utils/Lifebuoy.sol";
import { SSTORE2 } from "solady/utils/SSTORE2.sol";
import { LibString } from "solady/utils/LibString.sol";
import { LibZip } from "solady/utils/LibZip.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { IAdminControl } from "@manifoldxyz/libraries-solidity/contracts/access/IAdminControl.sol";

/**
 * @title Multiplex
 * @author Yigit Duman (@yigitduman)
 * @notice A universal URI distribution and management system for any contract
 */
contract Multiplex is Ownable, Lifebuoy {
    /*//////////////////////////////////////////////////////////////
                                ENUMS
    //////////////////////////////////////////////////////////////*/

    /// @notice Display modes for token rendering
    enum DisplayMode {
        DIRECT_FILE, // Shows selected artwork as static file
        HTML // Shows interactive HTML experience with all artworks

    }

    /// @notice Thumbnail storage type discriminator
    enum ThumbnailKind {
        ON_CHAIN, // Stored on-chain using SSTORE2
        OFF_CHAIN // Referenced by URI array

    }

    /// @notice Ownership check style
    enum OwnershipStyle {
        OWNER_OF, // Returns address, check if == msg.sender (e.g., ownerOf(tokenId))
        BALANCE_OF_ERC721, // Returns uint256, check if > 0 (e.g., balanceOf(address))
        BALANCE_OF_ERC1155, // Returns uint256, check if > 0 (e.g., balanceOf(address, tokenId))
        IS_APPROVED_FOR_ALL, // Returns bool, check if == true (e.g., isApprovedForAll(address, address))
        SIMPLE_BOOL // Returns bool, check if == true (e.g., isOwner(address))

    }

    /*//////////////////////////////////////////////////////////////
                            DATA STRUCTURES  
    //////////////////////////////////////////////////////////////*/

    /// @notice Artwork configuration and URIs
    struct Artwork {
        string[] artistUris; // Artist-curated artwork URIs
        string[] collectorUris; // Collector-added artwork URIs (HTML mode only)
        string mimeType; // MIME type of the artwork
        string fileHash; // Hash of the artwork for verification
        bool isAnimationUri; // If true, artwork goes in animation_url
        uint256 selectedArtistUriIndex; // 0-based index for selected artist URI
    }

    /// @notice Permission flags for artist and collector actions (bit-packed)
    struct Permissions {
        uint16 flags; // Bit-packed permissions
    }

    // Permission bit positions
    uint16 constant ARTIST_UPDATE_THUMB = 2 ** 0;
    uint16 constant ARTIST_UPDATE_META = 2 ** 1;
    uint16 constant ARTIST_CHOOSE_URIS = 2 ** 2;
    uint16 constant ARTIST_ADD_REMOVE = 2 ** 3;
    uint16 constant ARTIST_CHOOSE_THUMB = 2 ** 4;
    uint16 constant ARTIST_UPDATE_MODE = 2 ** 5;
    uint16 constant ARTIST_UPDATE_TEMPLATE = 2 ** 6;
    uint16 constant COLLECTOR_CHOOSE_URIS = 2 ** 7;
    uint16 constant COLLECTOR_ADD_REMOVE = 2 ** 8;
    uint16 constant COLLECTOR_CHOOSE_THUMB = 2 ** 9;
    uint16 constant COLLECTOR_UPDATE_MODE = 2 ** 10;

    /// @notice On-chain thumbnail stored using SSTORE2
    struct OnChainThumbnail {
        string mimeType; // MIME type (e.g., "image/webp")
        address[] chunks; // SSTORE2 storage addresses
        bool zipped; // True if compressed with FastLZ
    }

    /// @notice Off-chain thumbnail referenced by URIs
    struct OffChainThumbnail {
        string[] uris; // Available thumbnail URIs
        uint256 selectedUriIndex; // 0-based index
    }

    /// @notice Unified thumbnail structure
    struct Thumbnail {
        ThumbnailKind kind; // Whether thumbnail is on-chain or off-chain
        OnChainThumbnail onChain; // On-chain thumbnail data
        OffChainThumbnail offChain; // Off-chain thumbnail data
    }

    /// @notice Ownership check configuration
    struct OwnershipConfig {
        bytes4 selector; // Function selector (e.g., OwnershipSelectors.OWNER_OF, OwnershipSelectors.BALANCE_OF, or
            // custom)
        OwnershipStyle style; // How to interpret the result
    }

    /// @notice Complete token data
    struct Token {
        string metadata; // JSON metadata (that contains name, description, traits)
        Thumbnail thumbnail; // Unified thumbnail data
        Artwork artwork; // Artwork configuration and URIs
        Permissions permissions; // Permission flags for artist and collector actions
        DisplayMode displayMode; // Current display mode
        OwnershipConfig ownership; // How to check token ownership
        address[] htmlTemplatePointers; // Custom HTML template chunks for this token (empty = use default)
    }

    /// @notice Configuration for initializing token data
    struct InitConfig {
        string metadata;
        Artwork artwork;
        Thumbnail thumbnail;
        DisplayMode displayMode;
        Permissions permissions;
        OwnershipConfig ownership;
    }

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping: creator contract => tokenId => token data
    mapping(address => mapping(uint256 => Token)) public tokenData;

    /// @notice HTML template stored using SSTORE2 for gas efficiency
    address private defaultHtmlTemplatePointer;

    /*//////////////////////////////////////////////////////////////
                            CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/

    error WalletNotAdmin();
    error NotTokenOwner();
    error NotTokenOwnerOrAdmin();
    error InvalidOwnershipFunction();
    error InvalidIndexRange();
    error ArtistPermissionRevoked();
    error CollectorPermissionDenied();
    error InvalidThumbnailKind();
    error OnChainThumbnailEmpty();
    error InvalidMetadata();
    error InvalidArtworkUris();
    error InvalidMimeType();
    error InvalidFileHash();
    error InvalidSelectedArtistUriIndex();
    error InvalidSelectedThumbnailUriIndex();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event TokenDataInitialized(address indexed creator, uint256 indexed tokenId);
    event MetadataUpdated(address indexed creator, uint256 indexed tokenId);
    event ThumbnailUpdated(address indexed creator, uint256 indexed tokenId);
    event DisplayModeUpdated(address indexed creator, uint256 indexed tokenId, DisplayMode displayMode);
    event SelectedArtworkUriChanged(address indexed creator, uint256 indexed tokenId, uint256 newIndex);
    event SelectedThumbnailUriChanged(address indexed creator, uint256 indexed tokenId, uint256 newIndex);
    event ArtworkUrisAdded(address indexed creator, uint256 indexed tokenId, address indexed actor, uint256 count);
    event ArtworkUriRemoved(address indexed creator, uint256 indexed tokenId, address indexed actor, uint256 index);
    event ArtistPermissionsRevoked(address indexed creator, uint256 indexed tokenId, address indexed artist);
    event HtmlTemplateUpdated();

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Initialize the contract with an HTML template
    /// @param _htmlTemplate Initial HTML template with placeholders
    constructor(string memory _htmlTemplate) {
        defaultHtmlTemplatePointer = SSTORE2.write(bytes(_htmlTemplate));
        _initializeOwner(msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                            ACCESS HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Check if the caller is an admin of the contract
    /// @param contractAddress The contract to check admin status for
    /// @return True if caller is admin, false otherwise
    function _isContractAdmin(address contractAddress) internal view returns (bool) {
        // First try to check if it's a Manifold contract with AdminControl
        try IAdminControl(contractAddress).isAdmin(tx.origin) returns (bool isAdmin) {
            return isAdmin;
        } catch {
            // If not, check if it implements standard Ownable interface
            try Ownable(contractAddress).owner() returns (address contractOwner) {
                return tx.origin == contractOwner;
            } catch {
                // If neither, return false
                return false;
            }
        }
    }

    /// @notice Restricts function access to contract admins only
    /// @param contractAddress The contract to check admin status for
    modifier contractAdminRequired(address contractAddress) {
        require(_isContractAdmin(contractAddress), WalletNotAdmin());
        _;
    }

    /// @notice Check if a msg.sender owns a specific token
    /// @param contractAddress The token contract address
    /// @param tokenId The token ID to check ownership for
    /// @return True if msg.sender owns the token, false otherwise
    function _isTokenOwner(address contractAddress, uint256 tokenId) internal view returns (bool) {
        Token storage token = tokenData[contractAddress][tokenId];

        if (token.ownership.style == OwnershipStyle.OWNER_OF) {
            // Call function that returns address (e.g., ownerOf(tokenId))
            (bool success, bytes memory result) =
                contractAddress.staticcall(abi.encodeWithSelector(token.ownership.selector, tokenId));
            if (success && result.length >= 32) {
                address owner = abi.decode(result, (address));
                return owner == msg.sender;
            }
        } else if (token.ownership.style == OwnershipStyle.BALANCE_OF_ERC721) {
            // Call function that returns uint256 (e.g., balanceOf(address))
            (bool success, bytes memory result) =
                contractAddress.staticcall(abi.encodeWithSelector(token.ownership.selector, msg.sender));
            if (success && result.length >= 32) {
                uint256 balance = abi.decode(result, (uint256));
                return balance > 0;
            }
        } else if (token.ownership.style == OwnershipStyle.BALANCE_OF_ERC1155) {
            // Call function that returns uint256 (e.g., balanceOf(address, tokenId))
            (bool success, bytes memory result) =
                contractAddress.staticcall(abi.encodeWithSelector(token.ownership.selector, msg.sender, tokenId));
            if (success && result.length >= 32) {
                uint256 balance = abi.decode(result, (uint256));
                return balance > 0;
            }
        } else if (token.ownership.style == OwnershipStyle.IS_APPROVED_FOR_ALL) {
            // Call function that returns bool (e.g., isApprovedForAll(owner, operator))
            // This requires knowing the owner address, so we need to get it first
            // For now, we'll assume the selector takes (msg.sender, contractAddress)
            (bool success, bytes memory result) = contractAddress.staticcall(
                abi.encodeWithSelector(token.ownership.selector, msg.sender, contractAddress)
            );
            if (success && result.length >= 32) {
                bool approved = abi.decode(result, (bool));
                return approved;
            }
        } else if (token.ownership.style == OwnershipStyle.SIMPLE_BOOL) {
            // Call function that returns bool (e.g., isOwner(address))
            (bool success, bytes memory result) =
                contractAddress.staticcall(abi.encodeWithSelector(token.ownership.selector, msg.sender));
            if (success && result.length >= 32) {
                bool isOwner = abi.decode(result, (bool));
                return isOwner;
            }
        }

        return false;
    }

    /*//////////////////////////////////////////////////////////////
                        TOKEN INITIALIZATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Initialize token data
    /// @param contractAddress The token contract address
    /// @param tokenId The token ID to initialize
    /// @param config Initialization configuration
    /// @param thumbnailChunks On-chain thumbnail data chunks
    function initializeTokenData(
        address contractAddress,
        uint256 tokenId,
        InitConfig calldata config,
        bytes[] calldata thumbnailChunks
    )
        external
        contractAdminRequired(contractAddress)
    {
        Token storage token = tokenData[contractAddress][tokenId];

        // Set metadata and display mode
        token.metadata = config.metadata;
        token.displayMode = config.displayMode;

        // Set artwork data
        token.artwork = config.artwork;

        // Set permissions
        token.permissions = config.permissions;

        // Set ownership configuration
        token.ownership = config.ownership;

        // Set thumbnail data
        token.thumbnail = config.thumbnail;

        // Metadata Checks
        if (bytes(config.metadata).length == 0) {
            revert InvalidMetadata();
        }

        // Artwork Checks
        if (config.artwork.artistUris.length == 0) {
            revert InvalidArtworkUris();
        }

        if (bytes(config.artwork.mimeType).length == 0) {
            revert InvalidMimeType();
        }

        if (bytes(config.artwork.fileHash).length == 0) {
            revert InvalidFileHash();
        }

        if (config.artwork.selectedArtistUriIndex >= config.artwork.artistUris.length) {
            revert InvalidSelectedArtistUriIndex();
        }

        // Thumbnail Checks
        if (config.thumbnail.kind == ThumbnailKind.ON_CHAIN) {
            if (thumbnailChunks.length == 0) {
                revert OnChainThumbnailEmpty();
            }

            // Store on-chain thumbnail chunks
            for (uint256 i = 0; i < thumbnailChunks.length; i++) {
                token.thumbnail.onChain.chunks.push(SSTORE2.write(thumbnailChunks[i]));
            }
        }

        if (config.thumbnail.kind == ThumbnailKind.OFF_CHAIN) {
            if (config.thumbnail.offChain.uris.length == 0) {
                revert InvalidIndexRange();
            }
        }
        if (config.thumbnail.offChain.selectedUriIndex >= config.thumbnail.offChain.uris.length) {
            revert InvalidSelectedThumbnailUriIndex();
        }

        // Ownership Checks
        if (config.ownership.selector == bytes4(0)) {
            revert InvalidOwnershipFunction();
        }

        emit TokenDataInitialized(contractAddress, tokenId);
    }

    /// @notice Resolve thumbnail URI based on storage type
    /// @param token The token data
    /// @return Thumbnail URI as data URI or external URI
    function _resolveThumbnailUri(Token storage token) internal view returns (string memory) {
        if (token.thumbnail.kind == ThumbnailKind.ON_CHAIN) {
            bytes memory data = _loadOnChainThumbnail(token.thumbnail.onChain);
            return _encodeDataUri(token.thumbnail.onChain.mimeType, data, false);
        } else if (token.thumbnail.kind == ThumbnailKind.OFF_CHAIN) {
            if (token.thumbnail.offChain.selectedUriIndex < token.thumbnail.offChain.uris.length) {
                return token.thumbnail.offChain.uris[token.thumbnail.offChain.selectedUriIndex];
            }
        }
        revert InvalidThumbnailKind();
    }

    /// @notice Build combined artwork URIs for HTML template
    /// @param token The token data
    /// @return Comma-separated JSON array of URIs
    function _combinedArtworkUris(Token storage token) internal view returns (string memory) {
        string memory uriList = "";

        // Add artist URIs
        for (uint256 i = 0; i < token.artwork.artistUris.length; i++) {
            if (i > 0) uriList = string(abi.encodePacked(uriList, ","));
            uriList = string(abi.encodePacked(uriList, '"', token.artwork.artistUris[i], '"'));
        }

        // Add collector URIs
        for (uint256 i = 0; i < token.artwork.collectorUris.length; i++) {
            if (token.artwork.artistUris.length > 0 || i > 0) {
                uriList = string(abi.encodePacked(uriList, ","));
            }
            uriList = string(abi.encodePacked(uriList, '"', token.artwork.collectorUris[i], '"'));
        }

        return uriList;
    }

    /// @notice Load and decompress on-chain thumbnail from storage
    /// @param thumbnail The on-chain thumbnail data
    /// @return Raw thumbnail bytes
    function _loadOnChainThumbnail(OnChainThumbnail storage thumbnail) internal view returns (bytes memory) {
        bytes memory data;

        // Concatenate all chunks
        for (uint256 i = 0; i < thumbnail.chunks.length; i++) {
            if (thumbnail.chunks[i] != address(0)) {
                data = abi.encodePacked(data, SSTORE2.read(thumbnail.chunks[i]));
            }
        }

        // Decompress if needed
        if (thumbnail.zipped) {
            data = LibZip.flzDecompress(data);
        }

        return data;
    }

    /// @notice Load and combine HTML template chunks from storage
    /// @param templatePointers Array of template chunk addresses
    /// @return Combined HTML template string
    function _loadHtmlTemplate(address[] storage templatePointers) internal view returns (string memory) {
        bytes memory data;

        // Concatenate all chunks
        for (uint256 i = 0; i < templatePointers.length; i++) {
            if (templatePointers[i] != address(0)) {
                data = abi.encodePacked(data, SSTORE2.read(templatePointers[i]));
            }
        }

        return string(data);
    }

    /*//////////////////////////////////////////////////////////////
                        TOKEN DATA MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Update metadata (artist only, if permission allows)
    /// @param contractAddress The creator contract address
    /// @param tokenId The token ID
    /// @param newMetadata The new metadata JSON
    function updateMetadata(
        address contractAddress,
        uint256 tokenId,
        string calldata newMetadata
    )
        external
        contractAdminRequired(contractAddress)
    {
        Token storage token = tokenData[contractAddress][tokenId];
        require(token.permissions.flags & ARTIST_UPDATE_META != 0, ArtistPermissionRevoked());

        token.metadata = newMetadata;
        emit MetadataUpdated(contractAddress, tokenId);
    }

    /// @notice Update HTML template for a specific token (artist only, if permission allows)
    /// @param contractAddress The creator contract address
    /// @param tokenId The token ID
    /// @param templateParts The new HTML template parts (empty array to use default)
    function updateHtmlTemplate(
        address contractAddress,
        uint256 tokenId,
        string[] calldata templateParts
    )
        external
        contractAdminRequired(contractAddress)
    {
        Token storage token = tokenData[contractAddress][tokenId];
        require(token.permissions.flags & ARTIST_UPDATE_TEMPLATE != 0, ArtistPermissionRevoked());

        // Clear existing template pointers
        delete token.htmlTemplatePointers;

        // Store new template parts as SSTORE2 chunks
        if (templateParts.length > 0) {
            for (uint256 i = 0; i < templateParts.length; i++) {
                if (bytes(templateParts[i]).length > 0) {
                    token.htmlTemplatePointers.push(SSTORE2.write(bytes(templateParts[i])));
                }
            }
        }

        emit HtmlTemplateUpdated();
    }

    /// @notice Update thumbnail (artist only, if permission allows)
    /// @param contractAddress The creator contract address
    /// @param tokenId The token ID
    /// @param thumbnail The new thumbnail data
    /// @param thumbnailChunks On-chain thumbnail chunks (if thumbnail.kind == ON_CHAIN)
    function updateThumbnail(
        address contractAddress,
        uint256 tokenId,
        Thumbnail calldata thumbnail,
        bytes[] calldata thumbnailChunks
    )
        external
        contractAdminRequired(contractAddress)
    {
        Token storage token = tokenData[contractAddress][tokenId];
        require(token.permissions.flags & ARTIST_UPDATE_THUMB != 0, ArtistPermissionRevoked());

        // Validate thumbnail configuration
        if (thumbnail.kind == ThumbnailKind.ON_CHAIN) {
            require(thumbnailChunks.length > 0, InvalidIndexRange());
        } else if (thumbnail.kind == ThumbnailKind.OFF_CHAIN) {
            require(thumbnail.offChain.uris.length > 0, InvalidIndexRange());
        }

        // Clear existing thumbnail data
        delete token.thumbnail.onChain.chunks;
        delete token.thumbnail.offChain.uris;

        // Set new thumbnail data
        token.thumbnail = thumbnail;

        if (thumbnail.kind == ThumbnailKind.ON_CHAIN) {
            // Store new on-chain thumbnail chunks
            for (uint256 i = 0; i < thumbnailChunks.length; i++) {
                token.thumbnail.onChain.chunks.push(SSTORE2.write(thumbnailChunks[i]));
            }
        }

        emit ThumbnailUpdated(contractAddress, tokenId);
    }

    /// @notice Revoke specific artist permissions (artist only)
    /// @param contractAddress The creator contract address
    /// @param tokenId The token ID
    /// @param revokeUpdateThumbnail True to revoke thumbnail update permission
    /// @param revokeUpdateMetadata True to revoke metadata update permission
    /// @param revokeChooseUris True to revoke URI selection permission
    /// @param revokeAddRemoveUris True to revoke add/remove URI permission
    /// @param revokeChooseThumbnail True to revoke thumbnail selection permission
    /// @param revokeUpdateDisplayMode True to revoke display mode update permission
    /// @param revokeUpdateTemplate True to revoke HTML template update permission
    function revokeArtistPermissions(
        address contractAddress,
        uint256 tokenId,
        bool revokeUpdateThumbnail,
        bool revokeUpdateMetadata,
        bool revokeChooseUris,
        bool revokeAddRemoveUris,
        bool revokeChooseThumbnail,
        bool revokeUpdateDisplayMode,
        bool revokeUpdateTemplate
    )
        external
        contractAdminRequired(contractAddress)
    {
        Token storage token = tokenData[contractAddress][tokenId];

        // Revoke permissions by clearing the corresponding bits
        if (revokeUpdateThumbnail) {
            token.permissions.flags &= ~ARTIST_UPDATE_THUMB;
        }
        if (revokeUpdateMetadata) {
            token.permissions.flags &= ~ARTIST_UPDATE_META;
        }
        if (revokeChooseUris) {
            token.permissions.flags &= ~ARTIST_CHOOSE_URIS;
        }
        if (revokeAddRemoveUris) {
            token.permissions.flags &= ~ARTIST_ADD_REMOVE;
        }
        if (revokeChooseThumbnail) {
            token.permissions.flags &= ~ARTIST_CHOOSE_THUMB;
        }
        if (revokeUpdateDisplayMode) {
            token.permissions.flags &= ~ARTIST_UPDATE_MODE;
        }
        if (revokeUpdateTemplate) {
            token.permissions.flags &= ~ARTIST_UPDATE_TEMPLATE;
        }

        emit ArtistPermissionsRevoked(contractAddress, tokenId, msg.sender);
    }

    /// @notice Revoke all artist permissions (artist only)
    /// @param contractAddress The creator contract address
    /// @param tokenId The token ID
    function revokeAllArtistPermissions(
        address contractAddress,
        uint256 tokenId
    )
        external
        contractAdminRequired(contractAddress)
    {
        Token storage token = tokenData[contractAddress][tokenId];

        // Clear all artist permission bits
        token.permissions.flags &= ~(
            ARTIST_UPDATE_THUMB | ARTIST_UPDATE_META | ARTIST_CHOOSE_URIS | ARTIST_ADD_REMOVE | ARTIST_CHOOSE_THUMB
                | ARTIST_UPDATE_MODE | ARTIST_UPDATE_TEMPLATE
        );

        emit ArtistPermissionsRevoked(contractAddress, tokenId, msg.sender);
    }

    /// @notice Add artwork URIs (artist or collector, based on caller role)
    /// @param contractAddress The creator contract address
    /// @param tokenId The token ID
    /// @param uris The artwork URIs to add
    function addArtworkUris(address contractAddress, uint256 tokenId, string[] calldata uris) external {
        Token storage token = tokenData[contractAddress][tokenId];
        bool isArtist = _isContractAdmin(contractAddress);
        bool isCollector = _isTokenOwner(contractAddress, tokenId);

        require(isArtist || isCollector, NotTokenOwnerOrAdmin());

        if (isArtist) {
            require(token.permissions.flags & ARTIST_ADD_REMOVE != 0, ArtistPermissionRevoked());
            for (uint256 i = 0; i < uris.length; i++) {
                token.artwork.artistUris.push(uris[i]);
            }
        } else {
            require(token.permissions.flags & COLLECTOR_ADD_REMOVE != 0, CollectorPermissionDenied());
            for (uint256 i = 0; i < uris.length; i++) {
                token.artwork.collectorUris.push(uris[i]);
            }
        }

        emit ArtworkUrisAdded(contractAddress, tokenId, msg.sender, uris.length);
    }

    /// @notice Remove artwork URIs by indices (artist or collector, based on caller role)
    /// @param contractAddress The creator contract address
    /// @param tokenId The token ID
    /// @param indices The indices to remove (must be sorted in descending order)
    function removeArtworkUris(address contractAddress, uint256 tokenId, uint256[] calldata indices) external {
        Token storage token = tokenData[contractAddress][tokenId];
        bool isArtist = _isContractAdmin(contractAddress);
        bool isCollector = _isTokenOwner(contractAddress, tokenId);

        require(isArtist || isCollector, NotTokenOwnerOrAdmin());
        require(indices.length > 0, InvalidIndexRange());

        if (isArtist) {
            require(token.permissions.flags & ARTIST_ADD_REMOVE != 0, ArtistPermissionRevoked());

            // Remove in descending order to maintain indices
            for (uint256 i = 0; i < indices.length; i++) {
                uint256 index = indices[i];
                require(index < token.artwork.artistUris.length, InvalidIndexRange());

                // Move last element to deleted position and pop
                token.artwork.artistUris[index] = token.artwork.artistUris[token.artwork.artistUris.length - 1];
                token.artwork.artistUris.pop();
            }

            // Reset selection if out of bounds
            if (token.artwork.selectedArtistUriIndex >= token.artwork.artistUris.length) {
                token.artwork.selectedArtistUriIndex =
                    token.artwork.artistUris.length > 0 ? uint8(token.artwork.artistUris.length - 1) : 0;
            }
        } else {
            require(token.permissions.flags & COLLECTOR_ADD_REMOVE != 0, CollectorPermissionDenied());

            // Remove in descending order to maintain indices
            for (uint256 i = 0; i < indices.length; i++) {
                uint256 index = indices[i];
                require(index < token.artwork.collectorUris.length, InvalidIndexRange());

                // Move last element to deleted position and pop
                token.artwork.collectorUris[index] = token.artwork.collectorUris[token.artwork.collectorUris.length - 1];
                token.artwork.collectorUris.pop();
            }
        }

        for (uint256 i = 0; i < indices.length; i++) {
            emit ArtworkUriRemoved(contractAddress, tokenId, msg.sender, indices[i]);
        }
    }

    /// @notice Set selected artwork URI (artist or collector, based on permissions)
    /// @param contractAddress The creator contract address
    /// @param tokenId The token ID
    /// @param index The 0-based index to select
    function setSelectedUri(address contractAddress, uint256 tokenId, uint256 index) external {
        Token storage token = tokenData[contractAddress][tokenId];
        bool isArtist = _isContractAdmin(contractAddress);
        bool isCollector = _isTokenOwner(contractAddress, tokenId);

        require(isArtist || isCollector, NotTokenOwnerOrAdmin());

        if (isArtist) {
            require(token.permissions.flags & ARTIST_CHOOSE_URIS != 0, ArtistPermissionRevoked());
        } else {
            require(token.permissions.flags & COLLECTOR_CHOOSE_URIS != 0, CollectorPermissionDenied());
        }

        // Validate index (0-based)
        require(index < token.artwork.artistUris.length, InvalidIndexRange());

        token.artwork.selectedArtistUriIndex = index;
        emit SelectedArtworkUriChanged(contractAddress, tokenId, index);
    }

    /// @notice Set selected thumbnail URI (artist or collector, based on permissions, off-chain only)
    /// @param contractAddress The creator contract address
    /// @param tokenId The token ID
    /// @param index The 0-based index to select
    function setSelectedThumbnailUri(address contractAddress, uint256 tokenId, uint256 index) external {
        Token storage token = tokenData[contractAddress][tokenId];
        bool isArtist = _isContractAdmin(contractAddress);
        bool isCollector = _isTokenOwner(contractAddress, tokenId);

        require(isArtist || isCollector, NotTokenOwnerOrAdmin());
        require(token.thumbnail.kind == ThumbnailKind.OFF_CHAIN, InvalidThumbnailKind());

        if (isArtist) {
            require(token.permissions.flags & ARTIST_CHOOSE_THUMB != 0, ArtistPermissionRevoked());
        } else {
            require(token.permissions.flags & COLLECTOR_CHOOSE_THUMB != 0, CollectorPermissionDenied());
        }

        // Validate index (0-based)
        require(index < token.thumbnail.offChain.uris.length, InvalidIndexRange());

        token.thumbnail.offChain.selectedUriIndex = index;
        emit SelectedThumbnailUriChanged(contractAddress, tokenId, index);
    }

    /// @notice Set display mode (artist or collector, based on permissions)
    /// @param contractAddress The creator contract address
    /// @param tokenId The token ID
    /// @param displayMode The new display mode
    function setDisplayMode(address contractAddress, uint256 tokenId, DisplayMode displayMode) external {
        Token storage token = tokenData[contractAddress][tokenId];
        bool isArtist = _isContractAdmin(contractAddress);
        bool isCollector = _isTokenOwner(contractAddress, tokenId);

        require(isArtist || isCollector, NotTokenOwnerOrAdmin());

        if (isArtist) {
            require(token.permissions.flags & ARTIST_UPDATE_MODE != 0, ArtistPermissionRevoked());
        } else {
            require(token.permissions.flags & COLLECTOR_UPDATE_MODE != 0, CollectorPermissionDenied());
        }

        token.displayMode = displayMode;
        emit DisplayModeUpdated(contractAddress, tokenId, displayMode);
    }

    /*//////////////////////////////////////////////////////////////
                        TEMPLATE MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Update HTML template (contract admin only)
    /// @param newTemplate New HTML template
    function setDefaultHtmlTemplate(string calldata newTemplate) external onlyOwner {
        defaultHtmlTemplatePointer = SSTORE2.write(bytes(newTemplate));
        emit HtmlTemplateUpdated();
    }

    /// @notice Get current HTML template
    /// @return The HTML template
    function getDefaultHtmlTemplate() external view returns (string memory) {
        return string(SSTORE2.read(defaultHtmlTemplatePointer));
    }

    /*//////////////////////////////////////////////////////////////
                        RENDERING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Render the thumbnail as a data URI
    /// @param contractAddress The creator contract address
    /// @param tokenId The token ID
    /// @return Base64-encoded data URI of the thumbnail
    function renderImage(address contractAddress, uint256 tokenId) public view returns (string memory) {
        Token storage token = tokenData[contractAddress][tokenId];
        return _resolveThumbnailUri(token);
    }

    /// @notice Render the raw image bytes
    /// @param contractAddress The creator contract address
    /// @param tokenId The token ID
    /// @return Raw image bytes
    function renderRawImage(address contractAddress, uint256 tokenId) public view returns (bytes memory) {
        Token storage token = tokenData[contractAddress][tokenId];
        if (token.thumbnail.kind != ThumbnailKind.ON_CHAIN) {
            revert InvalidThumbnailKind();
        }

        return _loadOnChainThumbnail(token.thumbnail.onChain);
    }

    /// @notice Render HTML content with all artwork URIs
    /// @param contractAddress The creator contract address
    /// @param tokenId The token ID
    /// @return Base64-encoded HTML data URI
    function renderHTML(address contractAddress, uint256 tokenId) public view returns (string memory) {
        Token storage token = tokenData[contractAddress][tokenId];

        // Build combined URI list using helper function
        string memory uriList = _combinedArtworkUris(token);

        // Get HTML template (use token-specific template if available, otherwise use default)
        string memory htmlTemplate;
        if (token.htmlTemplatePointers.length > 0) {
            htmlTemplate = _loadHtmlTemplate(token.htmlTemplatePointers);
        } else {
            htmlTemplate = string(SSTORE2.read(defaultHtmlTemplatePointer));
        }

        // Replace placeholders in template
        string memory html = LibString.replace(htmlTemplate, "{{FILE_URIS}}", uriList);
        html = LibString.replace(html, "{{FILE_HASH}}", token.artwork.fileHash);

        return _encodeDataUri("text/html", bytes(html), true);
    }

    /// @notice Render the raw HTML content
    /// @param contractAddress The creator contract address
    /// @param tokenId The token ID
    /// @return Raw HTML content
    function renderRawHTML(address contractAddress, uint256 tokenId) external view returns (string memory) {
        Token storage token = tokenData[contractAddress][tokenId];

        // Build combined URI list using helper function
        string memory uriList = _combinedArtworkUris(token);

        // Get HTML template (use token-specific template if available, otherwise use default)
        string memory htmlTemplate;
        if (token.htmlTemplatePointers.length > 0) {
            htmlTemplate = _loadHtmlTemplate(token.htmlTemplatePointers);
        } else {
            htmlTemplate = string(SSTORE2.read(defaultHtmlTemplatePointer));
        }

        // Replace placeholders in template
        string memory html = LibString.replace(htmlTemplate, "{{FILE_URIS}}", uriList);
        html = LibString.replace(html, "{{FILE_HASH}}", token.artwork.fileHash);

        return html;
    }

    /// @notice Render complete metadata JSON
    /// @param contractAddress The creator contract address
    /// @param tokenId The token ID
    /// @return Complete metadata JSON as Base64 encoded data URI
    function renderMetadata(address contractAddress, uint256 tokenId) public view returns (string memory) {
        Token storage token = tokenData[contractAddress][tokenId];
        string memory json = token.metadata;

        if (token.displayMode == DisplayMode.HTML) {
            // HTML mode: thumbnail in image, HTML content in animation_url
            string memory thumbnailUri = _resolveThumbnailUri(token);
            json = _appendJsonField(json, string(abi.encodePacked('"image":"', thumbnailUri, '"')));

            string memory htmlUri = renderHTML(contractAddress, tokenId);
            json = _appendJsonField(json, string(abi.encodePacked('"animation_url":"', htmlUri, '"')));
        } else {
            // DIRECT_FILE mode
            if (!token.artwork.isAnimationUri) {
                // Static artwork: selected artwork goes in image field
                if (token.artwork.artistUris.length > 0) {
                    // Use selected artwork, or fallback to first if index out of range
                    uint256 artworkIndex = token.artwork.selectedArtistUriIndex < token.artwork.artistUris.length
                        ? token.artwork.selectedArtistUriIndex
                        : 0;
                    string memory artworkUri = token.artwork.artistUris[artworkIndex];
                    json = _appendJsonField(json, string(abi.encodePacked('"image":"', artworkUri, '"')));
                } else {
                    // No artist URIs at all, fallback to thumbnail
                    string memory thumbnailUri = _resolveThumbnailUri(token);
                    json = _appendJsonField(json, string(abi.encodePacked('"image":"', thumbnailUri, '"')));
                }
            } else {
                // Animation artwork: thumbnail in image, artwork in animation_url
                string memory thumbnailUri = _resolveThumbnailUri(token);
                json = _appendJsonField(json, string(abi.encodePacked('"image":"', thumbnailUri, '"')));

                // Get artwork URI for animation_url
                string memory artworkUri;
                if (token.artwork.selectedArtistUriIndex < token.artwork.artistUris.length) {
                    // Use selected artwork
                    artworkUri = token.artwork.artistUris[token.artwork.selectedArtistUriIndex];
                } else if (token.artwork.artistUris.length > 0) {
                    // Index out of range, use first artwork
                    artworkUri = token.artwork.artistUris[0];
                }

                if (bytes(artworkUri).length > 0) {
                    json = _appendJsonField(json, string(abi.encodePacked('"animation_url":"', artworkUri, '"')));
                }
            }
        }

        return _encodeDataUri("application/json", bytes(string(abi.encodePacked("{", json, "}"))), true);
    }

    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get all artist artwork URIs for a token
    /// @param contractAddress The creator contract address
    /// @param tokenId The token ID
    /// @return Array of artist artwork URIs
    function getArtistArtworkUris(address contractAddress, uint256 tokenId) external view returns (string[] memory) {
        return tokenData[contractAddress][tokenId].artwork.artistUris;
    }

    /// @notice Get all collector artwork URIs for a token
    /// @param contractAddress The creator contract address
    /// @param tokenId The token ID
    /// @return Array of collector artwork URIs
    function getCollectorArtworkUris(
        address contractAddress,
        uint256 tokenId
    )
        external
        view
        returns (string[] memory)
    {
        return tokenData[contractAddress][tokenId].artwork.collectorUris;
    }

    /// @notice Get all thumbnail URIs for a token (off-chain only)
    /// @param contractAddress The creator contract address
    /// @param tokenId The token ID
    /// @return Array of thumbnail URIs
    function getThumbnailUris(address contractAddress, uint256 tokenId) external view returns (string[] memory) {
        Token storage token = tokenData[contractAddress][tokenId];
        require(token.thumbnail.kind == ThumbnailKind.OFF_CHAIN, InvalidThumbnailKind());
        return token.thumbnail.offChain.uris;
    }

    /// @notice Get token permissions
    /// @param contractAddress The creator contract address
    /// @param tokenId The token ID
    /// @return The permissions struct
    function getPermissions(address contractAddress, uint256 tokenId) external view returns (Permissions memory) {
        return tokenData[contractAddress][tokenId].permissions;
    }

    /// @notice Get artwork configuration
    /// @param contractAddress The creator contract address
    /// @param tokenId The token ID
    /// @return The artwork struct
    function getArtwork(address contractAddress, uint256 tokenId) external view returns (Artwork memory) {
        return tokenData[contractAddress][tokenId].artwork;
    }

    /// @notice Get thumbnail kind and selected index
    /// @param contractAddress The creator contract address
    /// @param tokenId The token ID
    /// @return thumbnailKind The thumbnail storage type
    /// @return selectedIndex The selected thumbnail index (for off-chain)
    function getThumbnailInfo(
        address contractAddress,
        uint256 tokenId
    )
        external
        view
        returns (ThumbnailKind thumbnailKind, uint256 selectedIndex)
    {
        Token storage token = tokenData[contractAddress][tokenId];
        thumbnailKind = token.thumbnail.kind;
        selectedIndex = token.thumbnail.kind == ThumbnailKind.OFF_CHAIN ? token.thumbnail.offChain.selectedUriIndex : 0;
    }

    /// @notice Get ownership configuration
    /// @param contractAddress The contract address
    /// @param tokenId The token ID
    /// @return The ownership configuration
    function getOwnershipConfig(
        address contractAddress,
        uint256 tokenId
    )
        external
        view
        returns (OwnershipConfig memory)
    {
        return tokenData[contractAddress][tokenId].ownership;
    }

    /// @notice Get HTML template for a specific token
    /// @param contractAddress The contract address
    /// @param tokenId The token ID
    /// @return The HTML template (empty string if using default)
    function getTokenHtmlTemplate(address contractAddress, uint256 tokenId) external view returns (string memory) {
        Token storage token = tokenData[contractAddress][tokenId];
        if (token.htmlTemplatePointers.length > 0) {
            return _loadHtmlTemplate(token.htmlTemplatePointers);
        }
        return ""; // Empty string indicates default template is being used
    }

    /// @notice Get combined artwork URIs
    /// @param contractAddress The creator contract address
    /// @param tokenId The token ID
    /// @return Comma-separated JSON array of URIs
    function getCombinedArtworkUris(address contractAddress, uint256 tokenId) external view returns (string memory) {
        Token storage token = tokenData[contractAddress][tokenId];
        return _combinedArtworkUris(token);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Encode data as base64 data URI
    /// @param mimeType MIME type
    /// @param data Raw data
    /// @return Base64-encoded data URI
    function _encodeDataUri(
        string memory mimeType,
        bytes memory data,
        bool utf8Charset
    )
        internal
        pure
        returns (string memory)
    {
        string memory charset = utf8Charset ? ";charset=UTF-8" : "";
        return string(abi.encodePacked("data:", mimeType, charset, ";base64,", Base64.encode(data)));
    }

    /// @notice Append field to JSON
    /// @param json Existing JSON (without braces)
    /// @param field New field to append
    /// @return Updated JSON
    function _appendJsonField(string memory json, string memory field) internal pure returns (string memory) {
        if (bytes(json).length == 0) return field;
        return string(abi.encodePacked(json, ",", field));
    }
}
