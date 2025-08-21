// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

import { Base64 } from "solady/utils/Base64.sol";
import { Lifebuoy } from "solady/utils/Lifebuoy.sol";
import { SSTORE2 } from "solady/utils/SSTORE2.sol";
import { LibString } from "solady/utils/LibString.sol";
import { LibZip } from "solady/utils/LibZip.sol";
import { InflateLib } from "./lib/InflateLib.sol";
import { AdminControl } from "@manifoldxyz/libraries-solidity/contracts/access/AdminControl.sol";
import { ICreatorExtensionTokenURI } from
    "@manifoldxyz/creator-core-solidity/contracts/extensions/ICreatorExtensionTokenURI.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { IERC1155CreatorCore } from "@manifoldxyz/creator-core-solidity/contracts/core/IERC1155CreatorCore.sol";
import { IERC721CreatorCore } from "@manifoldxyz/creator-core-solidity/contracts/core/IERC721CreatorCore.sol";
import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title Multiplex
 * @author Yigit Duman (@yigitduman)
 * @notice A Manifold Creator Extension for minting tokens with multiple media pointers.
 */
contract Multiplex is AdminControl, ICreatorExtensionTokenURI, Lifebuoy {
    /*//////////////////////////////////////////////////////////////
                                ENUMS
    //////////////////////////////////////////////////////////////*/

    /// @notice Display modes for token rendering
    enum DisplayMode {
        IMAGE, // Shows selected artwork as static image
        HTML // Shows interactive HTML experience with all artworks

    }

    /*//////////////////////////////////////////////////////////////
                            DATA STRUCTURES  
    //////////////////////////////////////////////////////////////*/

    /// @notice Compressed file storage structure
    struct File {
        string mimeType; // MIME type (e.g., "image/webp")
        address[] chunks; // SSTORE2 storage addresses
        uint256 length; // Original uncompressed file length
        bool zipped; // True if compressed with FastLZ
        bool deflated; // True if compressed with DEFLATE
    }

    /// @notice Immutable token properties set at mint time
    struct ImmutableProperties {
        string imageHash; // Hash of the artwork for verification
        string imageMimeType; // MIME type of the artwork
        bool isAnimationUri; // If true, artwork goes in animation_url
        bool useOffchainThumbnail; // If true, use off-chain thumbnail in metadata
        bool allowCollectorAddArtwork; // If true, collector can add artwork URIs
        bool allowCollectorSelectArtistArtwork; // If true, collector can select artist artwork
        bool allowCollectorSelectArtistThumbnail; // If true, collector can select artist thumbnail
        bool allowCollectorToggleDisplayMode; // If true, collector can change display mode
    }

    /// @notice Off-chain URI lists
    struct OffChainData {
        string[] artistArtworkUris; // Artist-curated artwork URIs
        string[] collectorArtworkUris; // Collector-added artwork URIs (HTML mode only)
        string[] artistThumbnailUris; // Artist-curated thumbnail URIs
    }

    /// @notice Current selection indices
    struct Selection {
        uint256 selectedArtistArtworkIndex; // 1-based index (0 = invalid/none)
        uint256 selectedArtistThumbnailIndex; // 1-based index (0 = use on-chain)
    }

    /// @notice Complete token data
    struct Token {
        string metadata; // JSON metadata (without image/animation_url)
        File onChainThumbnail; // On-chain thumbnail data
        DisplayMode displayMode; // Current display mode
        ImmutableProperties immutableProperties; // Properties that cannot change after mint
        OffChainData offchain; // Off-chain URI lists
        Selection selection; // Current selections
        bool metadataLocked; // If true, metadata cannot be updated
        bool thumbnailLocked; // If true, thumbnail cannot be updated
    }

    /// @notice Parameters for minting new tokens (shared between ERC721 and ERC1155)
    struct MintParams {
        string metadata; // Initial metadata JSON
        File onChainThumbnail; // Thumbnail file configuration
        DisplayMode initialDisplayMode; // Starting display mode
        ImmutableProperties immutableProperties; // Immutable properties
        string[] seedArtistArtworkUris; // Initial artist artwork URIs
        string[] seedArtistThumbnailUris; // Initial artist thumbnail URIs
    }

    /// @notice Parameters for ERC1155 minting to multiple addresses
    struct MintERC1155Params {
        MintParams baseParams; // Base minting parameters
        address[] recipients; // Addresses to mint to
        uint256[] quantities; // Quantities for each recipient
    }

    /// @notice Parameters for ERC721 minting to multiple addresses
    struct MintERC721Params {
        MintParams baseParams; // Base minting parameters
        address[] recipients; // Addresses to mint to (quantity is always 1 each)
    }

    /// @notice Parameters for updating token properties
    struct UpdateParams {
        // Admin-only updates
        string metadata; // New metadata (empty string = no change)
        bool updateMetadata; // Flag to update metadata
        bytes[] thumbnailChunks; // New thumbnail chunks
        File thumbnailOptions; // Thumbnail file options
        bool updateThumbnail; // Flag to update thumbnail
        // Owner or admin updates (subject to immutable permissions)
        DisplayMode displayMode; // New display mode
        bool updateDisplayMode; // Flag to update display mode
        uint256 selectedArtistArtworkIndex; // New artist artwork selection
        bool updateSelectedArtistArtwork; // Flag to update selection
        uint256 selectedArtistThumbnailIndex; // New artist thumbnail selection
        bool updateSelectedArtistThumbnail; // Flag to update selection
    }

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping: creator contract => tokenId => token data
    mapping(address => mapping(uint256 => Token)) public tokenData;

    /// @notice HTML template for rendering interactive experiences
    string private htmlTemplate;

    /*//////////////////////////////////////////////////////////////
                            CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/

    error WalletNotAdmin();
    error NotTokenOwner();
    error NotTokenOwnerOrAdmin();
    error CreatorMustImplementCreatorCoreInterface();
    error AlreadyLocked();
    error InvalidIndexRange();
    error InvalidCompressionFlags();
    error CollectorAddingArtworkDisabled();
    error CollectorSelectingArtworkDisabled();
    error CollectorSelectingThumbnailDisabled();
    error CollectorTogglingDisplayModeDisabled();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event TokenMinted(address indexed creator, uint256 indexed tokenId, address indexed recipient, uint256 quantity);
    event BatchTokensMinted(address indexed creator, uint256 indexed firstTokenId, uint256 totalMinted);
    event MetadataUpdated(address indexed creator, uint256 indexed tokenId);
    event MetadataLocked(address indexed creator, uint256 indexed tokenId);
    event ThumbnailUpdated(address indexed creator, uint256 indexed tokenId, uint256 chunkCount);
    event ThumbnailLocked(address indexed creator, uint256 indexed tokenId);
    event DisplayModeUpdated(address indexed creator, uint256 indexed tokenId, DisplayMode displayMode);
    event SelectedArtistArtworkChanged(address indexed creator, uint256 indexed tokenId, uint256 newIndex);
    event SelectedArtistThumbnailChanged(address indexed creator, uint256 indexed tokenId, uint256 newIndex);
    event ArtistArtworkUrisAdded(address indexed creator, uint256 indexed tokenId, uint256 count);
    event ArtistArtworkUriRemoved(address indexed creator, uint256 indexed tokenId, uint256 index);
    event ArtistThumbnailUrisAdded(address indexed creator, uint256 indexed tokenId, uint256 count);
    event ArtistThumbnailUriRemoved(address indexed creator, uint256 indexed tokenId, uint256 index);
    event CollectorArtworkUrisAdded(address indexed creator, uint256 indexed tokenId, uint256 count);
    event HtmlTemplateUpdated();

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Initialize the contract with an HTML template
    /// @param _htmlTemplate Initial HTML template with placeholders
    constructor(string memory _htmlTemplate) {
        htmlTemplate = _htmlTemplate;
    }

    /*//////////////////////////////////////////////////////////////
                            ACCESS HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Check if the caller is an admin of the creator contract
    /// @param creatorContractAddress The creator contract to check admin status for
    /// @return True if caller is admin, false otherwise
    function isCreatorAdmin(address creatorContractAddress) internal view returns (bool) {
        AdminControl creatorCoreContract = AdminControl(creatorContractAddress);
        return creatorCoreContract.isAdmin(msg.sender);
    }

    /// @notice Check if a wallet owns a specific token
    /// @param creatorContractAddress The creator contract address
    /// @param tokenId The token ID to check ownership for
    /// @param wallet The wallet address to check
    /// @return True if wallet owns the token, false otherwise
    function isTokenOwner(
        address creatorContractAddress,
        uint256 tokenId,
        address wallet
    )
        internal
        view
        returns (bool)
    {
        if (isCreatorContractERC1155(creatorContractAddress)) {
            return IERC1155(creatorContractAddress).balanceOf(wallet, tokenId) > 0;
        } else if (isCreatorContractERC721(creatorContractAddress)) {
            return IERC721(creatorContractAddress).ownerOf(tokenId) == wallet;
        } else {
            revert CreatorMustImplementCreatorCoreInterface();
        }
    }

    /// @notice Check if creator contract supports ERC1155CreatorCore interface
    /// @param creatorContractAddress The contract address to check
    /// @return True if contract supports ERC1155CreatorCore
    function isCreatorContractERC1155(address creatorContractAddress) internal view returns (bool) {
        return ERC165Checker.supportsInterface(creatorContractAddress, type(IERC1155CreatorCore).interfaceId);
    }

    /// @notice Check if creator contract supports ERC721CreatorCore interface
    /// @param creatorContractAddress The contract address to check
    /// @return True if contract supports ERC721CreatorCore
    function isCreatorContractERC721(address creatorContractAddress) internal view returns (bool) {
        return ERC165Checker.supportsInterface(creatorContractAddress, type(IERC721CreatorCore).interfaceId);
    }

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Restricts function access to creator contract admins only
    /// @param creatorContractAddress The creator contract to check admin status for
    modifier creatorAdminRequired(address creatorContractAddress) {
        require(isCreatorAdmin(creatorContractAddress), WalletNotAdmin());
        _;
    }

    /// @notice Restricts function access to token owners only
    /// @param creatorContractAddress The creator contract address
    /// @param tokenId The token ID to check ownership for
    modifier tokenOwnerRequired(address creatorContractAddress, uint256 tokenId) {
        require(isTokenOwner(creatorContractAddress, tokenId, msg.sender), NotTokenOwner());
        _;
    }

    /// @notice Restricts function access to token owners or creator admins
    /// @param creatorContractAddress The creator contract address
    /// @param tokenId The token ID to check ownership for
    modifier tokenOwnerOrAdminRequired(address creatorContractAddress, uint256 tokenId) {
        require(
            isCreatorAdmin(creatorContractAddress) || isTokenOwner(creatorContractAddress, tokenId, msg.sender),
            NotTokenOwnerOrAdmin()
        );
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            MINTING
    //////////////////////////////////////////////////////////////*/

    /// @notice Mint ERC1155 tokens to multiple addresses with specified quantities
    /// @param creatorContractAddress The ERC1155 creator contract address
    /// @param params Minting parameters including recipients and quantities
    /// @param thumbnailChunks On-chain thumbnail data chunks
    function mintERC1155(
        address creatorContractAddress,
        MintERC1155Params calldata params,
        bytes[] calldata thumbnailChunks
    )
        external
        payable
        creatorAdminRequired(creatorContractAddress)
    {
        require(isCreatorContractERC1155(creatorContractAddress), CreatorMustImplementCreatorCoreInterface());
        require(params.recipients.length == params.quantities.length, InvalidIndexRange());
        require(params.recipients.length > 0, InvalidIndexRange());

        // Mint tokens via ERC1155 creator contract
        string[] memory uris = new string[](params.recipients.length);
        uint256[] memory tokenIds =
            IERC1155CreatorCore(creatorContractAddress).mintExtensionNew(params.recipients, params.quantities, uris);

        // Initialize and emit events
        _mint(
            creatorContractAddress, tokenIds, params.recipients, params.quantities, params.baseParams, thumbnailChunks
        );
    }

    /// @notice Mint ERC721 tokens to multiple addresses (one per address)
    /// @param creatorContractAddress The ERC721 creator contract address
    /// @param params Minting parameters including recipients
    /// @param thumbnailChunks On-chain thumbnail data chunks
    function mintERC721(
        address creatorContractAddress,
        MintERC721Params calldata params,
        bytes[] calldata thumbnailChunks
    )
        external
        payable
        creatorAdminRequired(creatorContractAddress)
    {
        require(isCreatorContractERC721(creatorContractAddress), CreatorMustImplementCreatorCoreInterface());
        require(params.recipients.length > 0, InvalidIndexRange());

        uint256[] memory tokenIds = new uint256[](params.recipients.length);
        uint256[] memory quantities = new uint256[](params.recipients.length);

        // Mint tokens to each recipient
        for (uint256 i = 0; i < params.recipients.length; i++) {
            tokenIds[i] = IERC721CreatorCore(creatorContractAddress).mintExtension(params.recipients[i]);
            quantities[i] = 1; // ERC721 always has quantity 1
        }

        // Initialize and emit events
        _mint(creatorContractAddress, tokenIds, params.recipients, quantities, params.baseParams, thumbnailChunks);
    }

    /*//////////////////////////////////////////////////////////////
                    ARTIST ARTWORK MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Add artist artwork URIs (artist only)
    /// @param creatorContractAddress The creator contract address
    /// @param tokenId The token ID
    /// @param uris The artwork URIs to add
    function addArtistArtworkUris(
        address creatorContractAddress,
        uint256 tokenId,
        string[] calldata uris
    )
        external
        creatorAdminRequired(creatorContractAddress)
    {
        Token storage token = tokenData[creatorContractAddress][tokenId];

        for (uint256 i = 0; i < uris.length; i++) {
            token.offchain.artistArtworkUris.push(uris[i]);
        }

        // If no artwork was selected before and we added some, select the first one
        if (token.selection.selectedArtistArtworkIndex == 0 && uris.length > 0) {
            token.selection.selectedArtistArtworkIndex = 1;
        }

        emit ArtistArtworkUrisAdded(creatorContractAddress, tokenId, uris.length);
    }

    /// @notice Remove an artist artwork URI by index (artist only)
    /// @param creatorContractAddress The creator contract address
    /// @param tokenId The token ID
    /// @param index The index to remove
    function removeArtistArtworkUri(
        address creatorContractAddress,
        uint256 tokenId,
        uint256 index
    )
        external
        creatorAdminRequired(creatorContractAddress)
    {
        Token storage token = tokenData[creatorContractAddress][tokenId];
        string[] storage artworks = token.offchain.artistArtworkUris;

        require(index < artworks.length, InvalidIndexRange());

        // Move last element to deleted position and pop
        artworks[index] = artworks[artworks.length - 1];
        artworks.pop();

        // Adjust selection if needed
        uint256 currentSelection = token.selection.selectedArtistArtworkIndex;
        if (currentSelection > 0) {
            // Convert to 0-based for comparison
            uint256 selectedIndex = currentSelection - 1;
            if (selectedIndex == index && artworks.length > 0) {
                // Selected item was removed, select first item
                token.selection.selectedArtistArtworkIndex = 1;
            } else if (selectedIndex == artworks.length) {
                // Selected item was moved from last position
                token.selection.selectedArtistArtworkIndex = index + 1;
            } else if (currentSelection > artworks.length) {
                // Selection is now out of bounds
                token.selection.selectedArtistArtworkIndex = artworks.length > 0 ? 1 : 0;
            }
        }

        emit ArtistArtworkUriRemoved(creatorContractAddress, tokenId, index);
    }

    /*//////////////////////////////////////////////////////////////
                    ARTIST THUMBNAIL MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Add artist thumbnail URIs (artist only)
    /// @param creatorContractAddress The creator contract address
    /// @param tokenId The token ID
    /// @param uris The thumbnail URIs to add
    function addArtistThumbnailUris(
        address creatorContractAddress,
        uint256 tokenId,
        string[] calldata uris
    )
        external
        creatorAdminRequired(creatorContractAddress)
    {
        Token storage token = tokenData[creatorContractAddress][tokenId];

        for (uint256 i = 0; i < uris.length; i++) {
            token.offchain.artistThumbnailUris.push(uris[i]);
        }

        emit ArtistThumbnailUrisAdded(creatorContractAddress, tokenId, uris.length);
    }

    /// @notice Remove an artist thumbnail URI by index (artist only)
    /// @param creatorContractAddress The creator contract address
    /// @param tokenId The token ID
    /// @param index The index to remove
    function removeArtistThumbnailUri(
        address creatorContractAddress,
        uint256 tokenId,
        uint256 index
    )
        external
        creatorAdminRequired(creatorContractAddress)
    {
        Token storage token = tokenData[creatorContractAddress][tokenId];
        string[] storage thumbnails = token.offchain.artistThumbnailUris;

        require(index < thumbnails.length, InvalidIndexRange());

        // Move last element to deleted position and pop
        thumbnails[index] = thumbnails[thumbnails.length - 1];
        thumbnails.pop();

        // Adjust selection if needed
        uint256 currentSelection = token.selection.selectedArtistThumbnailIndex;
        if (currentSelection > 0) {
            // Convert to 0-based for comparison
            uint256 selectedIndex = currentSelection - 1;
            if (selectedIndex == index && thumbnails.length > 0) {
                // Selected item was removed, select first item
                token.selection.selectedArtistThumbnailIndex = 1;
            } else if (selectedIndex == thumbnails.length) {
                // Selected item was moved from last position
                token.selection.selectedArtistThumbnailIndex = index + 1;
            } else if (currentSelection > thumbnails.length) {
                // Selection is now out of bounds, fallback to on-chain
                token.selection.selectedArtistThumbnailIndex = 0;
            }
        }

        emit ArtistThumbnailUriRemoved(creatorContractAddress, tokenId, index);
    }

    /*//////////////////////////////////////////////////////////////
                    COLLECTOR ARTWORK MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Add collector artwork URIs (collector only, if allowed)
    /// @param creatorContractAddress The creator contract address
    /// @param tokenId The token ID
    /// @param uris The artwork URIs to add
    function addCollectorArtworkUris(
        address creatorContractAddress,
        uint256 tokenId,
        string[] calldata uris
    )
        external
        tokenOwnerRequired(creatorContractAddress, tokenId)
    {
        Token storage token = tokenData[creatorContractAddress][tokenId];

        // Check if collector is allowed to add artwork
        require(token.immutableProperties.allowCollectorAddArtwork, CollectorAddingArtworkDisabled());

        for (uint256 i = 0; i < uris.length; i++) {
            token.offchain.collectorArtworkUris.push(uris[i]);
        }

        emit CollectorArtworkUrisAdded(creatorContractAddress, tokenId, uris.length);
    }

    /*//////////////////////////////////////////////////////////////
                        LOCK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Lock metadata to prevent future updates (artist only)
    /// @param creatorContractAddress The creator contract address
    /// @param tokenId The token ID
    function lockMetadata(
        address creatorContractAddress,
        uint256 tokenId
    )
        external
        creatorAdminRequired(creatorContractAddress)
    {
        Token storage token = tokenData[creatorContractAddress][tokenId];
        require(!token.metadataLocked, AlreadyLocked());

        token.metadataLocked = true;
        emit MetadataLocked(creatorContractAddress, tokenId);
    }

    /// @notice Lock thumbnail to prevent future updates (artist only)
    /// @param creatorContractAddress The creator contract address
    /// @param tokenId The token ID
    function lockThumbnail(
        address creatorContractAddress,
        uint256 tokenId
    )
        external
        creatorAdminRequired(creatorContractAddress)
    {
        Token storage token = tokenData[creatorContractAddress][tokenId];
        require(!token.thumbnailLocked, AlreadyLocked());

        token.thumbnailLocked = true;
        emit ThumbnailLocked(creatorContractAddress, tokenId);
    }

    /*//////////////////////////////////////////////////////////////
                        UPDATE FUNCTION
    //////////////////////////////////////////////////////////////*/

    /// @notice Update multiple token properties in one transaction
    /// @param creatorContractAddress The creator contract address
    /// @param tokenId The token ID
    /// @param params Update parameters
    function updateToken(address creatorContractAddress, uint256 tokenId, UpdateParams calldata params) external {
        Token storage token = tokenData[creatorContractAddress][tokenId];
        bool isAdmin = isCreatorAdmin(creatorContractAddress);
        bool isOwner = isTokenOwner(creatorContractAddress, tokenId, msg.sender);

        require(isAdmin || isOwner, NotTokenOwnerOrAdmin());

        // ADMIN-ONLY UPDATES

        // Update metadata
        if (params.updateMetadata) {
            require(isAdmin, WalletNotAdmin());
            require(!token.metadataLocked, AlreadyLocked());
            token.metadata = params.metadata;
            emit MetadataUpdated(creatorContractAddress, tokenId);
        }

        // Update thumbnail
        if (params.updateThumbnail) {
            require(isAdmin, WalletNotAdmin());
            require(!token.thumbnailLocked, AlreadyLocked());
            require(!(params.thumbnailOptions.zipped && params.thumbnailOptions.deflated), InvalidCompressionFlags());

            // Clear existing chunks
            delete token.onChainThumbnail.chunks;

            // Store new chunks
            for (uint256 i = 0; i < params.thumbnailChunks.length; i++) {
                token.onChainThumbnail.chunks.push(SSTORE2.write(params.thumbnailChunks[i]));
            }

            // Update file properties
            token.onChainThumbnail.mimeType = params.thumbnailOptions.mimeType;
            token.onChainThumbnail.length = params.thumbnailOptions.length;
            token.onChainThumbnail.zipped = params.thumbnailOptions.zipped;
            token.onChainThumbnail.deflated = params.thumbnailOptions.deflated;

            emit ThumbnailUpdated(creatorContractAddress, tokenId, params.thumbnailChunks.length);
        }

        // OWNER OR ADMIN UPDATES (with permission checks)

        // Update display mode
        if (params.updateDisplayMode) {
            if (!isAdmin) {
                require(
                    token.immutableProperties.allowCollectorToggleDisplayMode, CollectorTogglingDisplayModeDisabled()
                );
            }
            token.displayMode = params.displayMode;
            emit DisplayModeUpdated(creatorContractAddress, tokenId, params.displayMode);
        }

        // Update selected artist artwork
        if (params.updateSelectedArtistArtwork) {
            if (!isAdmin) {
                require(
                    token.immutableProperties.allowCollectorSelectArtistArtwork, CollectorSelectingArtworkDisabled()
                );
            }

            // Validate index (1-based, 0 means none)
            if (params.selectedArtistArtworkIndex > 0) {
                require(
                    params.selectedArtistArtworkIndex <= token.offchain.artistArtworkUris.length, InvalidIndexRange()
                );
            }

            token.selection.selectedArtistArtworkIndex = params.selectedArtistArtworkIndex;
            emit SelectedArtistArtworkChanged(creatorContractAddress, tokenId, params.selectedArtistArtworkIndex);
        }

        // Update selected artist thumbnail
        if (params.updateSelectedArtistThumbnail) {
            if (!isAdmin) {
                require(
                    token.immutableProperties.allowCollectorSelectArtistThumbnail, CollectorSelectingThumbnailDisabled()
                );
            }

            // Validate index (1-based, 0 means use on-chain)
            if (params.selectedArtistThumbnailIndex > 0) {
                require(
                    params.selectedArtistThumbnailIndex <= token.offchain.artistThumbnailUris.length,
                    InvalidIndexRange()
                );
            }

            token.selection.selectedArtistThumbnailIndex = params.selectedArtistThumbnailIndex;
            emit SelectedArtistThumbnailChanged(creatorContractAddress, tokenId, params.selectedArtistThumbnailIndex);
        }
    }

    /*//////////////////////////////////////////////////////////////
                        TEMPLATE MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Update HTML template (contract admin only)
    /// @param newTemplate New HTML template
    function setHtmlTemplate(string calldata newTemplate) external {
        require(isAdmin(msg.sender), WalletNotAdmin());
        htmlTemplate = newTemplate;
        emit HtmlTemplateUpdated();
    }

    /// @notice Get current HTML template
    /// @return The HTML template
    function getHtmlTemplate() external view returns (string memory) {
        return htmlTemplate;
    }

    /*//////////////////////////////////////////////////////////////
                        RENDERING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Render the on-chain thumbnail as a data URI
    /// @param creatorContractAddress The creator contract address
    /// @param tokenId The token ID
    /// @return Base64-encoded data URI of the thumbnail
    function renderImage(address creatorContractAddress, uint256 tokenId) public view returns (string memory) {
        Token storage token = tokenData[creatorContractAddress][tokenId];
        bytes memory data = _loadFile(token.onChainThumbnail);
        return _encodeDataUri(token.onChainThumbnail.mimeType, data);
    }

    /// @notice Render HTML content with all artwork URIs
    /// @param creatorContractAddress The creator contract address
    /// @param tokenId The token ID
    /// @return Base64-encoded HTML data URI
    function renderHTML(address creatorContractAddress, uint256 tokenId) public view returns (string memory) {
        Token storage token = tokenData[creatorContractAddress][tokenId];

        // Build combined URI list (artist + collector)
        string memory uriList = "";

        // Add artist URIs
        for (uint256 i = 0; i < token.offchain.artistArtworkUris.length; i++) {
            if (i > 0) uriList = string(abi.encodePacked(uriList, ","));
            uriList = string(abi.encodePacked(uriList, '"', token.offchain.artistArtworkUris[i], '"'));
        }

        // Add collector URIs
        for (uint256 i = 0; i < token.offchain.collectorArtworkUris.length; i++) {
            if (token.offchain.artistArtworkUris.length > 0 || i > 0) {
                uriList = string(abi.encodePacked(uriList, ","));
            }
            uriList = string(abi.encodePacked(uriList, '"', token.offchain.collectorArtworkUris[i], '"'));
        }

        // Replace placeholders in template
        string memory html = LibString.replace(htmlTemplate, "{{IMAGE_URIS}}", uriList);
        html = LibString.replace(html, "{{IMAGE_HASH}}", token.immutableProperties.imageHash);

        return string(abi.encodePacked("data:text/html;base64,", Base64.encode(bytes(html))));
    }

    /// @notice Render complete metadata JSON
    /// @param creatorContractAddress The creator contract address
    /// @param tokenId The token ID
    /// @return Complete metadata JSON as data URI
    function renderMetadata(address creatorContractAddress, uint256 tokenId) public view returns (string memory) {
        Token storage token = tokenData[creatorContractAddress][tokenId];
        string memory json = token.metadata;

        // Determine thumbnail to use
        string memory thumbnailUri;
        if (token.immutableProperties.useOffchainThumbnail && token.selection.selectedArtistThumbnailIndex > 0) {
            uint256 index = token.selection.selectedArtistThumbnailIndex - 1; // Convert to 0-based
            if (index < token.offchain.artistThumbnailUris.length) {
                thumbnailUri = token.offchain.artistThumbnailUris[index];
            } else {
                // Fallback to on-chain if index is out of range
                thumbnailUri = renderImage(creatorContractAddress, tokenId);
            }
        } else {
            // Use on-chain thumbnail
            thumbnailUri = renderImage(creatorContractAddress, tokenId);
        }

        // Add image field
        json = _appendJsonField(json, string(abi.encodePacked('"image":"', thumbnailUri, '"')));

        // Add animation_url if needed
        if (token.displayMode == DisplayMode.HTML) {
            // HTML mode: always show interactive experience
            string memory htmlUri = renderHTML(creatorContractAddress, tokenId);
            json = _appendJsonField(json, string(abi.encodePacked('"animation_url":"', htmlUri, '"')));
        } else if (token.immutableProperties.isAnimationUri && token.selection.selectedArtistArtworkIndex > 0) {
            // IMAGE mode with animation: show selected artist artwork
            uint256 index = token.selection.selectedArtistArtworkIndex - 1; // Convert to 0-based
            if (index < token.offchain.artistArtworkUris.length) {
                string memory artworkUri = token.offchain.artistArtworkUris[index];
                json = _appendJsonField(json, string(abi.encodePacked('"animation_url":"', artworkUri, '"')));
            }
            // If index is out of range, omit animation_url
        }

        return string(abi.encodePacked("data:application/json;utf8,{", json, "}"));
    }

    /*//////////////////////////////////////////////////////////////
                        INTERFACE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get token URI (ICreatorExtensionTokenURI implementation)
    /// @param creator The creator contract address
    /// @param tokenId The token ID
    /// @return Complete metadata JSON as data URI
    function tokenURI(address creator, uint256 tokenId) external view override returns (string memory) {
        return renderMetadata(creator, tokenId);
    }

    /// @notice Check if contract supports a given interface
    /// @param interfaceId The interface ID to check
    /// @return True if interface is supported
    function supportsInterface(bytes4 interfaceId) public view virtual override(AdminControl, IERC165) returns (bool) {
        return interfaceId == type(ICreatorExtensionTokenURI).interfaceId || AdminControl.supportsInterface(interfaceId);
    }

    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get all artist artwork URIs for a token
    /// @param creatorContractAddress The creator contract address
    /// @param tokenId The token ID
    /// @return Array of artist artwork URIs
    function getArtistArtworkUris(
        address creatorContractAddress,
        uint256 tokenId
    )
        external
        view
        returns (string[] memory)
    {
        return tokenData[creatorContractAddress][tokenId].offchain.artistArtworkUris;
    }

    /// @notice Get all collector artwork URIs for a token
    /// @param creatorContractAddress The creator contract address
    /// @param tokenId The token ID
    /// @return Array of collector artwork URIs
    function getCollectorArtworkUris(
        address creatorContractAddress,
        uint256 tokenId
    )
        external
        view
        returns (string[] memory)
    {
        return tokenData[creatorContractAddress][tokenId].offchain.collectorArtworkUris;
    }

    /// @notice Get all artist thumbnail URIs for a token
    /// @param creatorContractAddress The creator contract address
    /// @param tokenId The token ID
    /// @return Array of artist thumbnail URIs
    function getArtistThumbnailUris(
        address creatorContractAddress,
        uint256 tokenId
    )
        external
        view
        returns (string[] memory)
    {
        return tokenData[creatorContractAddress][tokenId].offchain.artistThumbnailUris;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Internal mint function to handle common minting logic
    /// @param creatorContractAddress The creator contract address
    /// @param tokenIds Array of minted token IDs
    /// @param recipients Array of recipient addresses
    /// @param quantities Array of quantities for each token
    /// @param params Base minting parameters
    /// @param thumbnailChunks On-chain thumbnail data chunks
    function _mint(
        address creatorContractAddress,
        uint256[] memory tokenIds,
        address[] memory recipients,
        uint256[] memory quantities,
        MintParams calldata params,
        bytes[] calldata thumbnailChunks
    )
        internal
    {
        // Validate compression settings
        require(!(params.onChainThumbnail.zipped && params.onChainThumbnail.deflated), InvalidCompressionFlags());

        // Initialize token data for the first token (all tokens share the same metadata)
        uint256 primaryTokenId = tokenIds[0];
        _initializeTokenData(creatorContractAddress, primaryTokenId, params, thumbnailChunks);

        // Emit events for each minted token
        for (uint256 i = 0; i < tokenIds.length; i++) {
            emit TokenMinted(creatorContractAddress, tokenIds[i], recipients[i], quantities[i]);
        }

        emit BatchTokensMinted(creatorContractAddress, primaryTokenId, tokenIds.length);
    }

    /// @notice Initialize token data for a newly minted token
    /// @param creatorContractAddress The creator contract address
    /// @param tokenId The token ID to initialize
    /// @param params Base minting parameters
    /// @param thumbnailChunks On-chain thumbnail data chunks
    function _initializeTokenData(
        address creatorContractAddress,
        uint256 tokenId,
        MintParams calldata params,
        bytes[] calldata thumbnailChunks
    )
        internal
    {
        Token storage token = tokenData[creatorContractAddress][tokenId];

        // Set metadata
        token.metadata = params.metadata;
        token.displayMode = params.initialDisplayMode;

        // Set immutable properties
        token.immutableProperties = params.immutableProperties;

        // Store on-chain thumbnail
        for (uint256 i = 0; i < thumbnailChunks.length; i++) {
            token.onChainThumbnail.chunks.push(SSTORE2.write(thumbnailChunks[i]));
        }
        token.onChainThumbnail.mimeType = params.onChainThumbnail.mimeType;
        token.onChainThumbnail.length = params.onChainThumbnail.length;
        token.onChainThumbnail.zipped = params.onChainThumbnail.zipped;
        token.onChainThumbnail.deflated = params.onChainThumbnail.deflated;

        // Seed initial URI lists
        for (uint256 i = 0; i < params.seedArtistArtworkUris.length; i++) {
            token.offchain.artistArtworkUris.push(params.seedArtistArtworkUris[i]);
        }
        for (uint256 i = 0; i < params.seedArtistThumbnailUris.length; i++) {
            token.offchain.artistThumbnailUris.push(params.seedArtistThumbnailUris[i]);
        }

        // Set default selections
        if (params.seedArtistArtworkUris.length > 0) {
            token.selection.selectedArtistArtworkIndex = 1; // First artwork
        }
    }

    /// @notice Load and decompress file from storage
    /// @param file The file to load
    /// @return Raw file bytes
    function _loadFile(File storage file) internal view returns (bytes memory) {
        bytes memory data;

        // Concatenate all chunks
        for (uint256 i = 0; i < file.chunks.length; i++) {
            if (file.chunks[i] != address(0)) {
                data = abi.encodePacked(data, SSTORE2.read(file.chunks[i]));
            }
        }

        // Decompress if needed
        if (file.zipped) {
            data = LibZip.flzDecompress(data);
        } else if (file.deflated) {
            data = InflateLib.puff(data, file.length);
        }

        return data;
    }

    /// @notice Encode data as base64 data URI
    /// @param mimeType MIME type
    /// @param data Raw data
    /// @return Base64-encoded data URI
    function _encodeDataUri(string memory mimeType, bytes memory data) internal pure returns (string memory) {
        return string(abi.encodePacked("data:", mimeType, ";base64,", Base64.encode(data)));
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
