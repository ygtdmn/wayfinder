// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

import { Base64 } from "solady/utils/Base64.sol";
import { Lifebuoy } from "solady/utils/Lifebuoy.sol";
import { SSTORE2 } from "solady/utils/SSTORE2.sol";
import { LibString } from "solady/utils/LibString.sol";
import { LibZip } from "solady/utils/LibZip.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { IAdminControl } from "@manifoldxyz/libraries-solidity/contracts/access/IAdminControl.sol";
import { IMultiplex } from "./interfaces/IMultiplex.sol";
import { IMultiplexCreator } from "./interfaces/IMultiplexCreator.sol";

/**
 * @title Multiplex
 * @author Yigit Duman (@yigitduman)
 * @notice A universal URI distribution and management system for any smart contract
 */
contract Multiplex is IMultiplex, Ownable, Lifebuoy {
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

    // Permission bit domains
    uint16 constant ARTIST_BITS_COUNT = 7; // Artist permissions occupy bits 0-6

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping: creator contract => tokenId => token data
    mapping(address => mapping(uint256 => Token)) public tokenData;

    /// @notice Mapping: creator contract => operator address for admin/ownership checks
    /// @dev Operator handles IMultiplexCreator interface calls.
    /// For most contracts, operator = contract itself.
    /// For Manifold/Transient extensions, operator = extension address.
    mapping(address => address) public contractOperators;

    /// @notice Default HTML template stored using SSTORE2 for gas efficiency
    HtmlTemplate private _defaultHtmlTemplate;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Initialize the contract with an HTML template
    /// @param _htmlTemplate Initial HTML template with placeholders
    /// @param _zipped True if the template is compressed with FastLZ
    constructor(string memory _htmlTemplate, bool _zipped) {
        _defaultHtmlTemplate.chunks.push(SSTORE2.write(bytes(_htmlTemplate)));
        _defaultHtmlTemplate.zipped = _zipped;
        _initializeOwner(msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                            ACCESS HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Check if account is owner/admin of a contract using fallback methods
    /// @param contractAddress The contract to check
    /// @param account The account to check
    /// @return True if account is owner/admin
    function _isContractAdmin(address contractAddress, address account) internal view returns (bool) {
        (bool ok, bytes memory ret) =
            contractAddress.staticcall(abi.encodeWithSelector(IAdminControl.isAdmin.selector, account));
        if (ok && ret.length >= 32) {
            return abi.decode(ret, (bool));
        }
        (ok, ret) = contractAddress.staticcall(abi.encodeWithSelector(Ownable.owner.selector));
        if (ok && ret.length >= 32) {
            return abi.decode(ret, (address)) == account;
        }
        return false;
    }

    /// @notice Restricts registration to contract owners/admins only
    /// @param contractAddress The contract to check ownership for
    modifier onlyContractOwner(address contractAddress) {
        require(_isContractAdmin(contractAddress, msg.sender), WalletNotAdmin());
        _;
    }

    /// @notice Restricts function access to registered contracts only
    /// @param contractAddress The contract to check registration for
    modifier onlyRegisteredContract(address contractAddress) {
        require(contractOperators[contractAddress] != address(0), ContractNotRegistered());
        _;
    }

    /// @notice Restricts function access to contract operators only
    /// @param contractAddress The contract to check operator for
    modifier onlyContractOperator(address contractAddress) {
        require(msg.sender == contractOperators[contractAddress], UnauthorizedOperator());
        _;
    }

    /// @notice Check if an account owns a specific token using registered implementation
    /// @param contractAddress The token contract address
    /// @param tokenId The token ID to check ownership for
    /// @param account The account to check ownership for
    /// @return True if account owns the token, false otherwise
    function _isTokenOwner(
        address contractAddress,
        uint256 tokenId,
        address account
    )
        internal
        view
        onlyRegisteredContract(contractAddress)
        returns (bool)
    {
        address operator = contractOperators[contractAddress];
        // Not doing try/catch here since any registered contract should implement the interface
        return IMultiplexCreator(operator).isTokenOwner(contractAddress, account, tokenId);
    }

    /*//////////////////////////////////////////////////////////////
                        CONTRACT INITIALIZATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Register a contract with its operator contract
    /// @param contractAddress The contract address
    /// @param operatorAddress The operator address (use address(0) to set as contractAddress)
    /// @dev Only the contract owner/admin can register. Operator handles IMultiplexCreator calls.
    function registerContract(
        address contractAddress,
        address operatorAddress
    )
        external
        onlyContractOwner(contractAddress)
    {
        // If operatorAddress is zero, use the contract address itself
        address operator = operatorAddress == address(0) ? contractAddress : operatorAddress;

        require(IMultiplexCreator(operator).supportsInterface(type(IMultiplexCreator).interfaceId), InvalidInterface());

        contractOperators[contractAddress] = operator;

        emit ContractRegistered(contractAddress, operator, msg.sender);
    }

        /// @notice Check if an address is the operator for a contract
    /// @param contractAddress The contract contract address
    /// @param operatorAddress The address to check
    /// @return True if operatorAddress is the operator for the contract
    function isContractOperator(address contractAddress, address operatorAddress) external view returns (bool) {
        return contractOperators[contractAddress] == operatorAddress;
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
        onlyRegisteredContract(contractAddress)
        onlyContractOperator(contractAddress)
    {
        Token storage token = tokenData[contractAddress][tokenId];

        // Set metadata and display mode
        token.metadata = config.metadata;
        token.displayMode = config.displayMode;

        // Set artwork data
        token.artwork = config.artwork;

        // Set permissions
        token.permissions = config.permissions;

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

        emit TokenDataInitialized(contractAddress, tokenId);
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
        onlyRegisteredContract(contractAddress)
        onlyContractOwner(contractAddress)
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
    /// @param zipped True if template parts are compressed with FastLZ
    function updateHtmlTemplate(
        address contractAddress,
        uint256 tokenId,
        string[] calldata templateParts,
        bool zipped
    )
        external
        onlyRegisteredContract(contractAddress)
        onlyContractOwner(contractAddress)
    {
        Token storage token = tokenData[contractAddress][tokenId];
        require(token.permissions.flags & ARTIST_UPDATE_TEMPLATE != 0, ArtistPermissionRevoked());

        // Clear existing template chunks
        delete token.htmlTemplate.chunks;

        // Set compression flag
        token.htmlTemplate.zipped = zipped;

        // Store new template parts as SSTORE2 chunks
        for (uint256 i = 0; i < templateParts.length; i++) {
            if (bytes(templateParts[i]).length > 0) {
                token.htmlTemplate.chunks.push(SSTORE2.write(bytes(templateParts[i])));
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
        onlyRegisteredContract(contractAddress)
        onlyContractOwner(contractAddress)
    {
        Token storage token = tokenData[contractAddress][tokenId];
        require(token.permissions.flags & ARTIST_UPDATE_THUMB != 0, ArtistPermissionRevoked());

        // Clear existing thumbnail data
        delete token.thumbnail.onChain.chunks;
        delete token.thumbnail.offChain.uris;

        // Validate thumbnail configuration
        if (thumbnail.kind == ThumbnailKind.ON_CHAIN) {
            require(thumbnailChunks.length > 0, InvalidIndexRange());

            // Store new on-chain thumbnail chunks
            for (uint256 i = 0; i < thumbnailChunks.length; i++) {
                token.thumbnail.onChain.chunks.push(SSTORE2.write(thumbnailChunks[i]));
            }
        } else {
            require(thumbnail.offChain.uris.length > 0, InvalidIndexRange());
        }

        // Set new thumbnail data
        token.thumbnail = thumbnail;
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
        onlyRegisteredContract(contractAddress)
        onlyContractOwner(contractAddress)
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
        onlyRegisteredContract(contractAddress)
        onlyContractOwner(contractAddress)
    {
        Token storage token = tokenData[contractAddress][tokenId];

        // Clear all artist permission bits (bits 0-6) using bit shifting
        token.permissions.flags = (token.permissions.flags >> ARTIST_BITS_COUNT) << ARTIST_BITS_COUNT;

        emit ArtistPermissionsRevoked(contractAddress, tokenId, msg.sender);
    }

    /// @notice Add artwork URIs (artist or collector, based on caller role)
    /// @param contractAddress The creator contract address
    /// @param tokenId The token ID
    /// @param uris The artwork URIs to add
    function addArtworkUris(
        address contractAddress,
        uint256 tokenId,
        string[] calldata uris
    )
        external
        onlyRegisteredContract(contractAddress)
    {
        Token storage token = tokenData[contractAddress][tokenId];

        // Check if caller is contract admin (artist)
        if (_isContractAdmin(contractAddress, msg.sender)) {
            require(token.permissions.flags & ARTIST_ADD_REMOVE != 0, ArtistPermissionRevoked());
            for (uint256 i = 0; i < uris.length; i++) {
                token.artwork.artistUris.push(uris[i]);
            }
            emit ArtworkUrisAdded(contractAddress, tokenId, msg.sender, uris.length);
            return;
        }

        // Check if caller is token owner (collector)
        if (_isTokenOwner(contractAddress, tokenId, msg.sender)) {
            require(token.permissions.flags & COLLECTOR_ADD_REMOVE != 0, CollectorPermissionDenied());
            for (uint256 i = 0; i < uris.length; i++) {
                token.artwork.collectorUris.push(uris[i]);
            }
            emit ArtworkUrisAdded(contractAddress, tokenId, msg.sender, uris.length);
            return;
        }

        revert NotTokenOwnerOrAdmin();
    }

    /// @notice Remove artwork URIs by indices (artist or collector, based on caller role)
    /// @param contractAddress The creator contract address
    /// @param tokenId The token ID
    /// @param indices The indices to remove (must be sorted in descending order)
    function removeArtworkUris(
        address contractAddress,
        uint256 tokenId,
        uint256[] calldata indices
    )
        external
        onlyRegisteredContract(contractAddress)
    {
        Token storage token = tokenData[contractAddress][tokenId];
        require(indices.length > 0, InvalidIndexRange());

        // Check if caller is contract admin (artist)
        if (_isContractAdmin(contractAddress, msg.sender)) {
            require(token.permissions.flags & ARTIST_ADD_REMOVE != 0, ArtistPermissionRevoked());

            // Remove in descending order to maintain indices
            for (uint256 i = 0; i < indices.length; i++) {
                // Validate descending order (skip first element)
                if (i > 0) {
                    require(indices[i] < indices[i - 1], InvalidIndexRange());
                }

                uint256 index = indices[i];
                require(index < token.artwork.artistUris.length, InvalidIndexRange());

                // Move last element to deleted position and pop
                token.artwork.artistUris[index] = token.artwork.artistUris[token.artwork.artistUris.length - 1];
                token.artwork.artistUris.pop();
                emit ArtworkUriRemoved(contractAddress, tokenId, msg.sender, indices[i]);
            }

            // Reset selection if out of bounds
            if (token.artwork.selectedArtistUriIndex >= token.artwork.artistUris.length) {
                token.artwork.selectedArtistUriIndex =
                    token.artwork.artistUris.length > 0 ? uint8(token.artwork.artistUris.length - 1) : 0;
            }
            return;
        }

        // Check if caller is token owner (collector)
        if (_isTokenOwner(contractAddress, tokenId, msg.sender)) {
            require(token.permissions.flags & COLLECTOR_ADD_REMOVE != 0, CollectorPermissionDenied());

            // Remove in descending order to maintain indices
            for (uint256 i = 0; i < indices.length; i++) {
                // Validate descending order (skip first element)
                if (i > 0) {
                    require(indices[i] < indices[i - 1], InvalidIndexRange());
                }

                uint256 index = indices[i];
                require(index < token.artwork.collectorUris.length, InvalidIndexRange());

                // Move last element to deleted position and pop
                token.artwork.collectorUris[index] = token.artwork.collectorUris[token.artwork.collectorUris.length - 1];
                token.artwork.collectorUris.pop();
                emit ArtworkUriRemoved(contractAddress, tokenId, msg.sender, indices[i]);
            }
            return;
        }

        revert NotTokenOwnerOrAdmin();
    }

    /// @notice Set selected artwork URI (artist or collector, based on permissions)
    /// @param contractAddress The creator contract address
    /// @param tokenId The token ID
    /// @param index The 0-based index to select
    function setSelectedUri(
        address contractAddress,
        uint256 tokenId,
        uint256 index
    )
        external
        onlyRegisteredContract(contractAddress)
    {
        Token storage token = tokenData[contractAddress][tokenId];

        // Check if caller is contract admin (artist)
        if (_isContractAdmin(contractAddress, msg.sender)) {
            require(token.permissions.flags & ARTIST_CHOOSE_URIS != 0, ArtistPermissionRevoked());
            // Validate index (0-based)
            require(index < token.artwork.artistUris.length, InvalidIndexRange());
            token.artwork.selectedArtistUriIndex = index;
            emit SelectedArtworkUriChanged(contractAddress, tokenId, index);
            return;
        }

        // Check if caller is token owner (collector)
        if (_isTokenOwner(contractAddress, tokenId, msg.sender)) {
            require(token.permissions.flags & COLLECTOR_CHOOSE_URIS != 0, CollectorPermissionDenied());
            // Validate index (0-based)
            require(index < token.artwork.artistUris.length, InvalidIndexRange());
            token.artwork.selectedArtistUriIndex = index;
            emit SelectedArtworkUriChanged(contractAddress, tokenId, index);
            return;
        }

        revert NotTokenOwnerOrAdmin();
    }

    /// @notice Set selected thumbnail URI (artist or collector, based on permissions, off-chain only)
    /// @param contractAddress The creator contract address
    /// @param tokenId The token ID
    /// @param index The 0-based index to select
    function setSelectedThumbnailUri(
        address contractAddress,
        uint256 tokenId,
        uint256 index
    )
        external
        onlyRegisteredContract(contractAddress)
    {
        Token storage token = tokenData[contractAddress][tokenId];
        require(token.thumbnail.kind == ThumbnailKind.OFF_CHAIN, InvalidThumbnailKind());

        // Check if caller is contract admin (artist)
        if (_isContractAdmin(contractAddress, msg.sender)) {
            require(token.permissions.flags & ARTIST_CHOOSE_THUMB != 0, ArtistPermissionRevoked());
            // Validate index (0-based)
            require(index < token.thumbnail.offChain.uris.length, InvalidIndexRange());
            token.thumbnail.offChain.selectedUriIndex = index;
            emit SelectedThumbnailUriChanged(contractAddress, tokenId, index);
            return;
        }

        // Check if caller is token owner (collector)
        if (_isTokenOwner(contractAddress, tokenId, msg.sender)) {
            require(token.permissions.flags & COLLECTOR_CHOOSE_THUMB != 0, CollectorPermissionDenied());
            // Validate index (0-based)
            require(index < token.thumbnail.offChain.uris.length, InvalidIndexRange());
            token.thumbnail.offChain.selectedUriIndex = index;
            emit SelectedThumbnailUriChanged(contractAddress, tokenId, index);
            return;
        }

        revert NotTokenOwnerOrAdmin();
    }

    /// @notice Set display mode (artist or collector, based on permissions)
    /// @param contractAddress The creator contract address
    /// @param tokenId The token ID
    /// @param displayMode The new display mode
    function setDisplayMode(
        address contractAddress,
        uint256 tokenId,
        DisplayMode displayMode
    )
        external
        onlyRegisteredContract(contractAddress)
    {
        Token storage token = tokenData[contractAddress][tokenId];

        // Check if caller is contract admin (artist)
        if (_isContractAdmin(contractAddress, msg.sender)) {
            require(token.permissions.flags & ARTIST_UPDATE_MODE != 0, ArtistPermissionRevoked());
            token.displayMode = displayMode;
            emit DisplayModeUpdated(contractAddress, tokenId, displayMode);
            return;
        }

        // Check if caller is token owner (collector)
        if (_isTokenOwner(contractAddress, tokenId, msg.sender)) {
            require(token.permissions.flags & COLLECTOR_UPDATE_MODE != 0, CollectorPermissionDenied());
            token.displayMode = displayMode;
            emit DisplayModeUpdated(contractAddress, tokenId, displayMode);
            return;
        }

        revert NotTokenOwnerOrAdmin();
    }

    /*//////////////////////////////////////////////////////////////
                        TEMPLATE MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Update HTML template (contract admin only)
    /// @param templateParts New HTML template parts
    /// @param zipped True if template parts are compressed with FastLZ
    function setDefaultHtmlTemplate(string[] calldata templateParts, bool zipped) external onlyOwner {
        // Clear existing template chunks
        delete _defaultHtmlTemplate.chunks;

        // Set compression flag
        _defaultHtmlTemplate.zipped = zipped;

        // Store new template parts as SSTORE2 chunks
        for (uint256 i = 0; i < templateParts.length; i++) {
            if (bytes(templateParts[i]).length > 0) {
                _defaultHtmlTemplate.chunks.push(SSTORE2.write(bytes(templateParts[i])));
            }
        }

        emit HtmlTemplateUpdated();
    }

    /// @notice Get current HTML template
    /// @return The HTML template
    function getDefaultHtmlTemplate() external view returns (string memory) {
        return _loadHtmlTemplate(_defaultHtmlTemplate);
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

    /// @notice Render the raw image bytes, on-chain only
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
        return _encodeDataUri("text/html", bytes(renderRawHTML(contractAddress, tokenId)), true);
    }

    /// @notice Render the raw HTML content
    /// @param contractAddress The creator contract address
    /// @param tokenId The token ID
    /// @return Raw HTML content
    function renderRawHTML(address contractAddress, uint256 tokenId) public view returns (string memory) {
        Token storage token = tokenData[contractAddress][tokenId];

        // Build combined URI list using helper function
        string memory uriList = _combinedArtworkUris(token);

        // Get HTML template (use token-specific template if available, otherwise use default)
        string memory htmlTemplate;
        if (token.htmlTemplate.chunks.length > 0) {
            htmlTemplate = _loadHtmlTemplate(token.htmlTemplate);
        } else {
            htmlTemplate = _loadHtmlTemplate(_defaultHtmlTemplate);
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
            json = _appendJsonField(json, LibString.concat(LibString.concat('"image":"', thumbnailUri), '"'));

            string memory htmlUri = renderHTML(contractAddress, tokenId);
            json = _appendJsonField(json, LibString.concat(LibString.concat('"animation_url":"', htmlUri), '"'));
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
                    json = _appendJsonField(json, LibString.concat(LibString.concat('"image":"', artworkUri), '"'));
                } else {
                    // No artist URIs at all, fallback to thumbnail
                    string memory thumbnailUri = _resolveThumbnailUri(token);
                    json = _appendJsonField(json, LibString.concat(LibString.concat('"image":"', thumbnailUri), '"'));
                }
            } else {
                // Animation artwork: thumbnail in image, artwork in animation_url
                string memory thumbnailUri = _resolveThumbnailUri(token);
                json = _appendJsonField(json, LibString.concat(LibString.concat('"image":"', thumbnailUri), '"'));

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
                    json =
                        _appendJsonField(json, LibString.concat(LibString.concat('"animation_url":"', artworkUri), '"'));
                }
            }
        }

        return _encodeDataUri("application/json", bytes(LibString.concat(LibString.concat("{", json), "}")), true);
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
        if (token.artwork.artistUris.length > 0) {
            // First artist URI (no comma)
            uriList = LibString.concat(LibString.concat('"', token.artwork.artistUris[0]), '"');

            // Remaining artist URIs (always with comma)
            for (uint256 i = 1; i < token.artwork.artistUris.length; i++) {
                uriList = LibString.concat(
                    LibString.concat(uriList, ',"'), LibString.concat(token.artwork.artistUris[i], '"')
                );
            }
        }

        // Add collector URIs
        if (token.artwork.collectorUris.length > 0) {
            // First collector URI (comma only if there are artist URIs)
            if (token.artwork.artistUris.length > 0) {
                uriList = LibString.concat(uriList, ",");
            }
            uriList =
                LibString.concat(LibString.concat(uriList, '"'), LibString.concat(token.artwork.collectorUris[0], '"'));

            // Remaining collector URIs (always with comma)
            for (uint256 i = 1; i < token.artwork.collectorUris.length; i++) {
                uriList = LibString.concat(
                    LibString.concat(uriList, ',"'), LibString.concat(token.artwork.collectorUris[i], '"')
                );
            }
        }

        return uriList;
    }

    /// @notice Generic function to load and decompress data from SSTORE2 chunks
    /// @param chunks Array of SSTORE2 storage addresses
    /// @param zipped True if data is compressed with FastLZ
    /// @return Raw decompressed data bytes
    function _loadFile(address[] memory chunks, bool zipped) internal view returns (bytes memory) {
        bytes memory data;

        // Concatenate all chunks
        for (uint256 i = 0; i < chunks.length; i++) {
            data = abi.encodePacked(data, SSTORE2.read(chunks[i]));
        }

        // Decompress if needed
        if (zipped) {
            data = LibZip.flzDecompress(data);
        }

        return data;
    }

    /// @notice Load and decompress on-chain thumbnail from storage
    /// @param thumbnail The on-chain thumbnail data
    /// @return Raw thumbnail bytes
    function _loadOnChainThumbnail(OnChainThumbnail storage thumbnail) internal view returns (bytes memory) {
        return _loadFile(thumbnail.chunks, thumbnail.zipped);
    }

    /// @notice Load and combine HTML template chunks from storage
    /// @param template The HTML template structure
    /// @return Combined HTML template string
    function _loadHtmlTemplate(HtmlTemplate storage template) internal view returns (string memory) {
        return string(_loadFile(template.chunks, template.zipped));
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

    /// @notice Get HTML template for a specific token
    /// @param contractAddress The contract address
    /// @param tokenId The token ID
    /// @return The HTML template (empty string if using default)
    function getTokenHtmlTemplate(address contractAddress, uint256 tokenId) external view returns (string memory) {
        Token storage token = tokenData[contractAddress][tokenId];
        if (token.htmlTemplate.chunks.length > 0) {
            return _loadHtmlTemplate(token.htmlTemplate);
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
        return LibString.concat(
            LibString.concat("data:", mimeType),
            LibString.concat(LibString.concat(charset, ";base64,"), Base64.encode(data))
        );
    }

    /// @notice Append field to JSON
    /// @param json Existing JSON (without braces)
    /// @param field New field to append
    /// @return Updated JSON
    function _appendJsonField(string memory json, string memory field) internal pure returns (string memory) {
        if (bytes(json).length == 0) return field;
        return LibString.concat(LibString.concat(json, ","), field);
    }
}
