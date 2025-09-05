// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/**
 * @title IWayfinder
 * @author Yigit Duman (@yigitduman)
 * @notice Interface for the Wayfinder contract
 */
interface IWayfinder {
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

    /// @notice HTML template stored using SSTORE2
    struct HtmlTemplate {
        address[] chunks; // SSTORE2 storage addresses
        bool zipped; // True if compressed with FastLZ
    }

    /// @notice Complete token data
    struct Token {
        string metadata; // JSON metadata (that contains name, description, traits)
        Thumbnail thumbnail; // Unified thumbnail data
        Artwork artwork; // Artwork configuration and URIs
        Permissions permissions; // Permission flags for artist and collector actions
        DisplayMode displayMode; // Current display mode
        HtmlTemplate htmlTemplate; // Custom HTML template for this token (empty chunks = use default)
    }

    /// @notice Configuration for initializing token data
    struct InitConfig {
        string metadata;
        Artwork artwork;
        Thumbnail thumbnail;
        DisplayMode displayMode;
        Permissions permissions;
        HtmlTemplate htmlTemplate;
    }

    /*//////////////////////////////////////////////////////////////
                            CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/

    error WalletNotAdmin();
    error NotTokenOwner();
    error NotTokenOwnerOrAdmin();
    error InvalidIndexRange();
    error ContractNotRegistered();
    error UnauthorizedOperator();
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
    error InvalidInterface();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event ContractRegistered(
        address indexed contractAddress, address indexed implementationAddress, address indexed registerer
    );
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
                        COLLECTION REGISTRATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Register a contract with its operator contract
    /// @param contractAddress The contract contract address
    /// @param operatorAddress The operator address (use address(0) to set as contractAddress)
    function registerContract(address contractAddress, address operatorAddress) external;

    /// @notice Check if an address is the operator for a contract
    /// @param contractAddress The contract contract address
    /// @param operatorAddress The address to check
    /// @return True if operatorAddress is the operator for the contract
    function isContractOperator(address contractAddress, address operatorAddress) external view returns (bool);

    /*//////////////////////////////////////////////////////////////
                        TOKEN INITIALIZATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Initialize token data
    /// @param contractAddress The token contract address
    /// @param tokenId The token ID to initialize
    /// @param config Initialization configuration
    /// @param thumbnailChunks On-chain thumbnail data chunks
    /// @param htmlTemplateChunks HTML template chunks (if config.htmlTemplate has empty chunks, use these)
    function initializeTokenData(
        address contractAddress,
        uint256 tokenId,
        InitConfig calldata config,
        bytes[] calldata thumbnailChunks,
        string[] calldata htmlTemplateChunks
    )
        external;

    /*//////////////////////////////////////////////////////////////
                        TOKEN DATA MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Update metadata (artist only, if permission allows)
    /// @param contractAddress The creator contract address
    /// @param tokenId The token ID
    /// @param newMetadata The new metadata JSON
    function updateMetadata(address contractAddress, uint256 tokenId, string calldata newMetadata) external;

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
        external;

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
        external;

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
        external;

    /// @notice Revoke all artist permissions (artist only)
    /// @param contractAddress The creator contract address
    /// @param tokenId The token ID
    function revokeAllArtistPermissions(address contractAddress, uint256 tokenId) external;

    /// @notice Add artwork URIs (artist or collector, based on caller role)
    /// @param contractAddress The creator contract address
    /// @param tokenId The token ID
    /// @param uris The artwork URIs to add
    function addArtworkUris(address contractAddress, uint256 tokenId, string[] calldata uris) external;

    /// @notice Remove artwork URIs by indices (artist or collector, based on caller role)
    /// @param contractAddress The creator contract address
    /// @param tokenId The token ID
    /// @param indices The indices to remove (must be sorted in descending order)
    function removeArtworkUris(address contractAddress, uint256 tokenId, uint256[] calldata indices) external;

    /// @notice Set selected artwork URI (artist or collector, based on permissions)
    /// @param contractAddress The creator contract address
    /// @param tokenId The token ID
    /// @param index The 0-based index to select
    function setSelectedUri(address contractAddress, uint256 tokenId, uint256 index) external;

    /// @notice Set selected thumbnail URI (artist or collector, based on permissions, off-chain only)
    /// @param contractAddress The creator contract address
    /// @param tokenId The token ID
    /// @param index The 0-based index to select
    function setSelectedThumbnailUri(address contractAddress, uint256 tokenId, uint256 index) external;

    /// @notice Set display mode (artist or collector, based on permissions)
    /// @param contractAddress The creator contract address
    /// @param tokenId The token ID
    /// @param displayMode The new display mode
    function setDisplayMode(address contractAddress, uint256 tokenId, DisplayMode displayMode) external;

    /*//////////////////////////////////////////////////////////////
                        TEMPLATE MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Update HTML template (contract admin only)
    /// @param templateParts New HTML template parts
    /// @param zipped True if template parts are compressed with FastLZ
    function setDefaultHtmlTemplate(string[] calldata templateParts, bool zipped) external;

    /// @notice Get current HTML template
    /// @return The HTML template
    function getDefaultHtmlTemplate() external view returns (string memory);

    /*//////////////////////////////////////////////////////////////
                        RENDERING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Render the thumbnail as a data URI
    /// @param contractAddress The creator contract address
    /// @param tokenId The token ID
    /// @return Base64-encoded data URI of the thumbnail
    function renderImage(address contractAddress, uint256 tokenId) external view returns (string memory);

    /// @notice Render the raw image bytes
    /// @param contractAddress The creator contract address
    /// @param tokenId The token ID
    /// @return Raw image bytes
    function renderRawImage(address contractAddress, uint256 tokenId) external view returns (bytes memory);

    /// @notice Render HTML content with all artwork URIs
    /// @param contractAddress The creator contract address
    /// @param tokenId The token ID
    /// @return Base64-encoded HTML data URI
    function renderHTML(address contractAddress, uint256 tokenId) external view returns (string memory);

    /// @notice Render the raw HTML content
    /// @param contractAddress The creator contract address
    /// @param tokenId The token ID
    /// @return Raw HTML content
    function renderRawHTML(address contractAddress, uint256 tokenId) external view returns (string memory);

    /// @notice Render complete metadata JSON
    /// @param contractAddress The creator contract address
    /// @param tokenId The token ID
    /// @return Complete metadata JSON as Base64 encoded data URI
    function renderMetadata(address contractAddress, uint256 tokenId) external view returns (string memory);

    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get all artist artwork URIs for a token
    /// @param contractAddress The creator contract address
    /// @param tokenId The token ID
    /// @return Array of artist artwork URIs
    function getArtistArtworkUris(address contractAddress, uint256 tokenId) external view returns (string[] memory);

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
        returns (string[] memory);

    /// @notice Get all thumbnail URIs for a token (off-chain only)
    /// @param contractAddress The creator contract address
    /// @param tokenId The token ID
    /// @return Array of thumbnail URIs
    function getThumbnailUris(address contractAddress, uint256 tokenId) external view returns (string[] memory);

    /// @notice Get token permissions
    /// @param contractAddress The creator contract address
    /// @param tokenId The token ID
    /// @return The permissions struct
    function getPermissions(address contractAddress, uint256 tokenId) external view returns (Permissions memory);

    /// @notice Get artwork configuration
    /// @param contractAddress The creator contract address
    /// @param tokenId The token ID
    /// @return The artwork struct
    function getArtwork(address contractAddress, uint256 tokenId) external view returns (Artwork memory);

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
        returns (ThumbnailKind thumbnailKind, uint256 selectedIndex);

    /// @notice Get HTML template for a specific token
    /// @param contractAddress The contract address
    /// @param tokenId The token ID
    /// @return The HTML template (empty string if using default)
    function getTokenHtmlTemplate(address contractAddress, uint256 tokenId) external view returns (string memory);

    /// @notice Get combined artwork URIs
    /// @param contractAddress The creator contract address
    /// @param tokenId The token ID
    /// @return Comma-separated JSON array of URIs
    function getCombinedArtworkUris(address contractAddress, uint256 tokenId) external view returns (string memory);
}
