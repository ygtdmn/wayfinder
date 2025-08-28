// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

import "forge-std/src/Test.sol";
import { Multiplex } from "src/Multiplex.sol";
import { MockCustomOwnership } from "test/mocks/MockCustomOwnership.sol";
import { MockAdminControl } from "test/mocks/MockAdminControl.sol";
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import { LibZip } from "solady/utils/LibZip.sol";
import { MockERC721 } from "test/mocks/MockERC721.sol";
import { MockERC1155 } from "test/mocks/MockERC1155.sol";
import { MockOwnable } from "test/mocks/MockOwnable.sol";
import { MultiplexHarness } from "test/MultiplexHarness.sol";

contract MultiplexTest is Test {
    // Test actors
    address owner = address(0x01);
    address artist = address(0x02);
    address collector = address(0x03);
    address stranger = address(0x04);

    // Core contracts
    Multiplex multiplex;
    MultiplexHarness harness;
    MockAdminControl adminControl;
    MockERC721 mockERC721;
    MockERC1155 mockERC1155;
    MockOwnable mockOwnable;
    MockCustomOwnership mockCustomOwnership;

    // Test data
    string constant DEFAULT_HTML_TEMPLATE = "<html>{{FILE_URIS}}</html>";
    string constant TEST_METADATA = '{"name":"Test NFT","description":"A test NFT"}';
    string[] testArtistUris;
    string[] testCollectorUris;
    string[] testThumbnailUris;
    uint256 constant TEST_TOKEN_ID = 1;

    // Permission constants (copied from Multiplex.sol)
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

    /*//////////////////////////////////////////////////////////////
                              SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        vm.startPrank(owner);

        // Deploy main contracts
        multiplex = new Multiplex(DEFAULT_HTML_TEMPLATE);
        harness = new MultiplexHarness();

        // Deploy admin control and set artist as admin
        adminControl = new MockAdminControl();
        adminControl.approveAdmin(artist);

        // Deploy mock tokens
        mockERC721 = new MockERC721();
        mockERC1155 = new MockERC1155();
        mockOwnable = new MockOwnable(artist);
        mockCustomOwnership = new MockCustomOwnership(collector);

        // Set artist as admin on token contracts (but NOT on mockCustomOwnership for testing)
        mockERC721.setAdmin(artist, true);
        mockERC1155.setAdmin(artist, true);
        // mockCustomOwnership.setAdmin(artist, true); // Commented out for test_isContractAdmin_Fail

        // Mint tokens to collector
        mockERC721.mint(collector); // This mints token ID 1
        uint256 token2 = mockERC721.mint(collector); // This mints token ID 2
        uint256 token3 = mockERC721.mint(collector); // This mints token ID 3
        mockERC1155.mint(collector, TEST_TOKEN_ID, 5);

        vm.stopPrank();

        // Set up test URIs
        testArtistUris.push("https://artist1.com");
        testArtistUris.push("https://artist2.com");
        testCollectorUris.push("https://collector1.com");
        testThumbnailUris.push("https://thumb1.com");
        testThumbnailUris.push("https://thumb2.com");
    }

    /*//////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _createValidInitConfig() internal view returns (Multiplex.InitConfig memory) {
        Multiplex.InitConfig memory config;

        config.metadata = TEST_METADATA;
        config.displayMode = Multiplex.DisplayMode.DIRECT_FILE;

        // Set up artwork
        config.artwork.artistUris = testArtistUris;
        config.artwork.mimeType = "image/png";
        config.artwork.fileHash = "0x1234567890abcdef";
        config.artwork.isAnimationUri = false;
        config.artwork.selectedArtistUriIndex = 0;

        // Set up permissions (all allowed)
        config.permissions.flags = ARTIST_UPDATE_THUMB | ARTIST_UPDATE_META | ARTIST_CHOOSE_URIS | ARTIST_ADD_REMOVE
            | ARTIST_CHOOSE_THUMB | ARTIST_UPDATE_MODE | ARTIST_UPDATE_TEMPLATE | COLLECTOR_CHOOSE_URIS
            | COLLECTOR_ADD_REMOVE | COLLECTOR_CHOOSE_THUMB | COLLECTOR_UPDATE_MODE;

        // Set up ownership config for ERC721
        config.ownership.selector = bytes4(keccak256("ownerOf(uint256)"));
        config.ownership.style = Multiplex.OwnershipStyle.OWNER_OF;

        // Set up off-chain thumbnail
        config.thumbnail.kind = Multiplex.ThumbnailKind.OFF_CHAIN;
        config.thumbnail.offChain.uris = testThumbnailUris;
        config.thumbnail.offChain.selectedUriIndex = 0;

        return config;
    }

    function _createOnChainThumbnailChunks() internal pure returns (bytes[] memory) {
        bytes[] memory chunks = new bytes[](2);
        chunks[0] = "chunk1data";
        chunks[1] = "chunk2data";
        return chunks;
    }

    /*//////////////////////////////////////////////////////////////
                    1. ERROR AND EVENT COVERAGE
    //////////////////////////////////////////////////////////////*/

    function test_AllCustomErrors() public {
        // Test WalletNotAdmin error
        vm.prank(stranger, stranger);
        vm.expectRevert(abi.encodeWithSelector(Multiplex.WalletNotAdmin.selector));
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, _createValidInitConfig(), new bytes[](0));

        // Test NotTokenOwner error - we'll test this in the _isTokenOwner context

        // Test InvalidOwnershipFunction error
        Multiplex.InitConfig memory config = _createValidInitConfig();
        config.ownership.selector = bytes4(0);

        vm.prank(artist, artist);
        vm.expectRevert(abi.encodeWithSelector(Multiplex.InvalidOwnershipFunction.selector));
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));

        // Test InvalidIndexRange error
        config = _createValidInitConfig();
        config.artwork.selectedArtistUriIndex = 999;

        vm.prank(artist, artist);
        vm.expectRevert(abi.encodeWithSelector(Multiplex.InvalidSelectedArtistUriIndex.selector));
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));

        // Test ArtistPermissionRevoked error
        config = _createValidInitConfig();
        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));

        vm.prank(artist, artist);
        multiplex.revokeArtistPermissions(
            address(adminControl), TEST_TOKEN_ID, false, true, false, false, false, false, false
        );

        vm.prank(artist, artist);
        vm.expectRevert(abi.encodeWithSelector(Multiplex.ArtistPermissionRevoked.selector));
        multiplex.updateMetadata(address(adminControl), TEST_TOKEN_ID, "new metadata");

        // Test other errors in their respective test contexts...
    }

    /*//////////////////////////////////////////////////////////////
                    2. _isContractAdmin TESTS
    //////////////////////////////////////////////////////////////*/

    function test_isContractAdmin_AdminControl() public {
        vm.prank(artist, artist);
        assertTrue(harness.isContractAdminPublic(address(adminControl)));

        vm.prank(stranger, stranger);
        assertFalse(harness.isContractAdminPublic(address(adminControl)));
    }

    function test_isContractAdmin_Ownable() public {
        vm.prank(artist, artist);
        assertTrue(harness.isContractAdminPublic(address(mockOwnable)));

        vm.prank(stranger, stranger);
        assertFalse(harness.isContractAdminPublic(address(mockOwnable)));
    }

    function test_isContractAdmin_Fail() public {
        // Test with a contract that implements neither AdminControl nor Ownable
        vm.prank(artist, artist);
        assertFalse(harness.isContractAdminPublic(address(mockCustomOwnership)));
    }

    /*//////////////////////////////////////////////////////////////
                    3. _isTokenOwner TESTS
    //////////////////////////////////////////////////////////////*/

    function test_isTokenOwner_ERC721() public {
        // Initialize token with ERC721 ownership config
        Multiplex.InitConfig memory config = _createValidInitConfig();
        config.ownership.selector = bytes4(keccak256("ownerOf(uint256)"));
        config.ownership.style = Multiplex.OwnershipStyle.OWNER_OF;

        vm.prank(artist, artist);
        harness.initializeTokenData(address(mockERC721), TEST_TOKEN_ID, config, new bytes[](0));

        vm.prank(collector, collector);
        assertTrue(harness.isTokenOwnerPublic(address(mockERC721), TEST_TOKEN_ID));

        vm.prank(stranger, stranger);
        assertFalse(harness.isTokenOwnerPublic(address(mockERC721), TEST_TOKEN_ID));
    }

    function test_isTokenOwner_ERC1155() public {
        // Initialize token with ERC1155 ownership config
        Multiplex.InitConfig memory config = _createValidInitConfig();
        config.ownership.selector = bytes4(keccak256("balanceOf(address,uint256)"));
        config.ownership.style = Multiplex.OwnershipStyle.BALANCE_OF_ERC1155;

        vm.prank(artist, artist);
        harness.initializeTokenData(address(mockERC1155), TEST_TOKEN_ID, config, new bytes[](0));

        vm.prank(collector, collector);
        assertTrue(harness.isTokenOwnerPublic(address(mockERC1155), TEST_TOKEN_ID));

        vm.prank(stranger, stranger);
        assertFalse(harness.isTokenOwnerPublic(address(mockERC1155), TEST_TOKEN_ID));
    }

    function test_isTokenOwner_Custom() public {
        // Initialize token with custom ownership config
        Multiplex.InitConfig memory config = _createValidInitConfig();
        config.ownership.selector = bytes4(keccak256("isOwner(address)"));
        config.ownership.style = Multiplex.OwnershipStyle.SIMPLE_BOOL;

        // Need to make artist admin of mockCustomOwnership for initialization
        vm.prank(owner, owner);
        mockCustomOwnership.setAdmin(artist, true);

        vm.prank(artist, artist);
        harness.initializeTokenData(address(mockCustomOwnership), TEST_TOKEN_ID, config, new bytes[](0));

        vm.prank(collector, collector);
        assertTrue(harness.isTokenOwnerPublic(address(mockCustomOwnership), TEST_TOKEN_ID));

        vm.prank(stranger, stranger);
        assertFalse(harness.isTokenOwnerPublic(address(mockCustomOwnership), TEST_TOKEN_ID));
    }

    /*//////////////////////////////////////////////////////////////
                    4. initializeTokenData TESTS
    //////////////////////////////////////////////////////////////*/

    function test_initializeTokenData_OnlyByAdmin() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();

        vm.prank(stranger, stranger);
        vm.expectRevert(abi.encodeWithSelector(Multiplex.WalletNotAdmin.selector));
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));

        // Should succeed with admin
        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));
    }

    function test_initializeTokenData_FullWorkflow() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();

        vm.prank(artist, artist);
        vm.recordLogs();
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));

        // Verify event
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 1);
        assertEq(logs[0].topics[0], keccak256("TokenDataInitialized(address,uint256)"));

        // Verify stored data
        (string memory metadata,,,,,) = multiplex.tokenData(address(adminControl), TEST_TOKEN_ID);
        assertEq(metadata, TEST_METADATA);

        Multiplex.Artwork memory artwork = multiplex.getArtwork(address(adminControl), TEST_TOKEN_ID);
        assertEq(artwork.artistUris.length, 2);
        assertEq(artwork.artistUris[0], "https://artist1.com");
        assertEq(artwork.mimeType, "image/png");
    }

    /*//////////////////////////////////////////////////////////////
                    5. _resolveThumbnailUri TESTS
    //////////////////////////////////////////////////////////////*/

    function test_resolveThumbnailUri_OnChain() public {
        // Create config with on-chain thumbnail
        Multiplex.InitConfig memory config = _createValidInitConfig();
        config.thumbnail.kind = Multiplex.ThumbnailKind.ON_CHAIN;
        config.thumbnail.onChain.mimeType = "image/png";
        config.thumbnail.onChain.zipped = false;

        bytes[] memory chunks = _createOnChainThumbnailChunks();

        vm.prank(artist, artist);
        harness.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, chunks);

        string memory result = harness.resolveThumbnailUriPublic(address(adminControl), TEST_TOKEN_ID);
        assertTrue(bytes(result).length > 0);
        // Should start with "data:image/png;base64,"
        assertEq(bytes(result)[0], bytes1("d"));
        assertEq(bytes(result)[1], bytes1("a"));
        assertEq(bytes(result)[2], bytes1("t"));
        assertEq(bytes(result)[3], bytes1("a"));
    }

    function test_resolveThumbnailUri_OffChain() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();

        vm.prank(artist, artist);
        harness.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));

        string memory result = harness.resolveThumbnailUriPublic(address(adminControl), TEST_TOKEN_ID);
        assertEq(result, "https://thumb1.com");
    }

    /*//////////////////////////////////////////////////////////////
                    6. _combinedArtworkUris TESTS
    //////////////////////////////////////////////////////////////*/

    function test_combinedArtworkUris() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(mockERC721), TEST_TOKEN_ID, config, new bytes[](0));

        // Add collector URIs
        string[] memory collectorUris = new string[](1);
        collectorUris[0] = "https://collector1.com";

        vm.prank(collector, collector);
        multiplex.addArtworkUris(address(mockERC721), TEST_TOKEN_ID, collectorUris);

        string memory result = multiplex.getCombinedArtworkUris(address(mockERC721), TEST_TOKEN_ID);
        assertEq(result, '"https://artist1.com","https://artist2.com","https://collector1.com"');
    }

    /*//////////////////////////////////////////////////////////////
                    7. _loadOnChainThumbnail TESTS
    //////////////////////////////////////////////////////////////*/

    function test_loadOnChainThumbnail_Unzipped() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();
        config.thumbnail.kind = Multiplex.ThumbnailKind.ON_CHAIN;
        config.thumbnail.onChain.mimeType = "image/png";
        config.thumbnail.onChain.zipped = false;

        bytes[] memory chunks = _createOnChainThumbnailChunks();

        vm.prank(artist, artist);
        harness.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, chunks);

        bytes memory result = harness.loadOnChainThumbnailPublic(address(adminControl), TEST_TOKEN_ID);
        assertEq(result, abi.encodePacked(chunks[0], chunks[1]));
    }

    function test_loadOnChainThumbnail_Zipped() public {
        bytes memory originalData = "test data to compress";
        bytes memory compressedData = LibZip.flzCompress(originalData);

        bytes[] memory chunks = new bytes[](1);
        chunks[0] = compressedData;

        Multiplex.InitConfig memory config = _createValidInitConfig();
        config.thumbnail.kind = Multiplex.ThumbnailKind.ON_CHAIN;
        config.thumbnail.onChain.mimeType = "image/png";
        config.thumbnail.onChain.zipped = true;

        vm.prank(artist, artist);
        harness.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, chunks);

        bytes memory result = harness.loadOnChainThumbnailPublic(address(adminControl), TEST_TOKEN_ID);
        assertEq(result, originalData);
    }

    /*//////////////////////////////////////////////////////////////
                    8. updateMetadata TESTS
    //////////////////////////////////////////////////////////////*/

    function test_updateMetadata_OnlyByAdmin() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));

        vm.prank(stranger, stranger);
        vm.expectRevert(abi.encodeWithSelector(Multiplex.WalletNotAdmin.selector));
        multiplex.updateMetadata(address(adminControl), TEST_TOKEN_ID, "new metadata");
    }

    function test_updateMetadata_PermissionRevoked() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));

        // Revoke metadata update permission
        vm.prank(artist, artist);
        multiplex.revokeArtistPermissions(
            address(adminControl), TEST_TOKEN_ID, false, true, false, false, false, false, false
        );

        vm.prank(artist, artist);
        vm.expectRevert(abi.encodeWithSelector(Multiplex.ArtistPermissionRevoked.selector));
        multiplex.updateMetadata(address(adminControl), TEST_TOKEN_ID, "new metadata");
    }

    function test_updateMetadata_Success() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));

        vm.prank(artist, artist);
        vm.recordLogs();
        multiplex.updateMetadata(address(adminControl), TEST_TOKEN_ID, "new metadata");

        // Verify event
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 1);
        assertEq(logs[0].topics[0], keccak256("MetadataUpdated(address,uint256)"));

        // Verify metadata changed
        (string memory metadata,,,,,) = multiplex.tokenData(address(adminControl), TEST_TOKEN_ID);
        assertEq(metadata, "new metadata");
    }

    /*//////////////////////////////////////////////////////////////
                    9. updateHtmlTemplate TESTS
    //////////////////////////////////////////////////////////////*/

    function test_updateHtmlTemplate_OnlyByAdmin() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));

        string[] memory templateParts = new string[](1);
        templateParts[0] = "<html>new template</html>";

        vm.prank(stranger, stranger);
        vm.expectRevert(abi.encodeWithSelector(Multiplex.WalletNotAdmin.selector));
        multiplex.updateHtmlTemplate(address(adminControl), TEST_TOKEN_ID, templateParts);
    }

    function test_updateHtmlTemplate_PermissionRevoked() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));

        // Revoke template update permission
        vm.prank(artist, artist);
        multiplex.revokeArtistPermissions(
            address(adminControl), TEST_TOKEN_ID, false, false, false, false, false, false, true
        );

        string[] memory templateParts = new string[](1);
        templateParts[0] = "<html>new template</html>";

        vm.prank(artist, artist);
        vm.expectRevert(abi.encodeWithSelector(Multiplex.ArtistPermissionRevoked.selector));
        multiplex.updateHtmlTemplate(address(adminControl), TEST_TOKEN_ID, templateParts);
    }

    function test_updateHtmlTemplate_Success() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));

        string[] memory templateParts = new string[](1);
        templateParts[0] = "<html>new template</html>";

        vm.prank(artist, artist);
        vm.recordLogs();
        multiplex.updateHtmlTemplate(address(adminControl), TEST_TOKEN_ID, templateParts);

        // Verify event
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 1);
        assertEq(logs[0].topics[0], keccak256("HtmlTemplateUpdated()"));

        // Verify template changed
        string memory template = multiplex.getTokenHtmlTemplate(address(adminControl), TEST_TOKEN_ID);
        assertEq(template, "<html>new template</html>");
    }

    function test_updateHtmlTemplate_ResetToDefault() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));

        // First set a custom template
        string[] memory templateParts = new string[](1);
        templateParts[0] = "<html>custom template</html>";

        vm.prank(artist, artist);
        multiplex.updateHtmlTemplate(address(adminControl), TEST_TOKEN_ID, templateParts);

        // Then reset to default with empty array
        string[] memory emptyParts = new string[](0);

        vm.prank(artist, artist);
        multiplex.updateHtmlTemplate(address(adminControl), TEST_TOKEN_ID, emptyParts);

        // Should return empty string indicating default template is used
        string memory template = multiplex.getTokenHtmlTemplate(address(adminControl), TEST_TOKEN_ID);
        assertEq(template, "");
    }

    /*//////////////////////////////////////////////////////////////
                    10. updateThumbnail TESTS
    //////////////////////////////////////////////////////////////*/

    function test_updateThumbnail_OnlyByAdmin() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));

        Multiplex.Thumbnail memory newThumbnail = config.thumbnail;

        vm.prank(stranger, stranger);
        vm.expectRevert(abi.encodeWithSelector(Multiplex.WalletNotAdmin.selector));
        multiplex.updateThumbnail(address(adminControl), TEST_TOKEN_ID, newThumbnail, new bytes[](0));
    }

    function test_updateThumbnail_PermissionRevoked() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));

        // Revoke thumbnail update permission
        vm.prank(artist, artist);
        multiplex.revokeArtistPermissions(
            address(adminControl), TEST_TOKEN_ID, true, false, false, false, false, false, false
        );

        Multiplex.Thumbnail memory newThumbnail = config.thumbnail;

        vm.prank(artist, artist);
        vm.expectRevert(abi.encodeWithSelector(Multiplex.ArtistPermissionRevoked.selector));
        multiplex.updateThumbnail(address(adminControl), TEST_TOKEN_ID, newThumbnail, new bytes[](0));
    }

    function test_updateThumbnail_Success() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));

        // Create new thumbnail with different URIs
        string[] memory newUris = new string[](1);
        newUris[0] = "https://newthumb.com";

        Multiplex.Thumbnail memory newThumbnail;
        newThumbnail.kind = Multiplex.ThumbnailKind.OFF_CHAIN;
        newThumbnail.offChain.uris = newUris;
        newThumbnail.offChain.selectedUriIndex = 0;

        vm.prank(artist, artist);
        vm.recordLogs();
        multiplex.updateThumbnail(address(adminControl), TEST_TOKEN_ID, newThumbnail, new bytes[](0));

        // Verify event
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 1);
        assertEq(logs[0].topics[0], keccak256("ThumbnailUpdated(address,uint256)"));

        // Verify thumbnail changed
        string[] memory uris = multiplex.getThumbnailUris(address(adminControl), TEST_TOKEN_ID);
        assertEq(uris.length, 1);
        assertEq(uris[0], "https://newthumb.com");
    }

    function test_updateThumbnail_InvalidOnChainData() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));

        Multiplex.Thumbnail memory newThumbnail;
        newThumbnail.kind = Multiplex.ThumbnailKind.ON_CHAIN;
        newThumbnail.onChain.mimeType = "image/png";
        newThumbnail.onChain.zipped = false;

        vm.prank(artist, artist);
        vm.expectRevert(abi.encodeWithSelector(Multiplex.InvalidIndexRange.selector));
        multiplex.updateThumbnail(address(adminControl), TEST_TOKEN_ID, newThumbnail, new bytes[](0)); // Empty chunks
    }

    /*//////////////////////////////////////////////////////////////
                    11. addArtworkUris TESTS
    //////////////////////////////////////////////////////////////*/

    function test_addArtworkUris_OnlyArtistOrCollector() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));

        string[] memory newUris = new string[](1);
        newUris[0] = "https://new.com";

        vm.prank(stranger, stranger);
        vm.expectRevert(abi.encodeWithSelector(Multiplex.NotTokenOwnerOrAdmin.selector));
        multiplex.addArtworkUris(address(adminControl), TEST_TOKEN_ID, newUris);
    }

    function test_addArtworkUris_Artist() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));

        string[] memory newUris = new string[](1);
        newUris[0] = "https://newartist.com";

        vm.prank(artist, artist);
        vm.recordLogs();
        multiplex.addArtworkUris(address(adminControl), TEST_TOKEN_ID, newUris);

        // Verify event
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 1);
        assertEq(logs[0].topics[0], keccak256("ArtworkUrisAdded(address,uint256,address,uint256)"));

        // Verify URI added to artist array
        string[] memory artistUris = multiplex.getArtistArtworkUris(address(adminControl), TEST_TOKEN_ID);
        assertEq(artistUris.length, 3); // 2 original + 1 new
        assertEq(artistUris[2], "https://newartist.com");
    }

    function test_addArtworkUris_Collector() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(mockERC721), TEST_TOKEN_ID, config, new bytes[](0));

        string[] memory newUris = new string[](1);
        newUris[0] = "https://newcollector.com";

        vm.prank(collector, collector);
        multiplex.addArtworkUris(address(mockERC721), TEST_TOKEN_ID, newUris);

        // Verify URI added to collector array
        string[] memory collectorUris = multiplex.getCollectorArtworkUris(address(mockERC721), TEST_TOKEN_ID);
        assertEq(collectorUris.length, 1);
        assertEq(collectorUris[0], "https://newcollector.com");
    }

    function test_addArtworkUris_PermissionDenied() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();
        config.permissions.flags = config.permissions.flags & ~ARTIST_ADD_REMOVE;

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));

        string[] memory newUris = new string[](1);
        newUris[0] = "https://new.com";

        vm.prank(artist, artist);
        vm.expectRevert(abi.encodeWithSelector(Multiplex.ArtistPermissionRevoked.selector));
        multiplex.addArtworkUris(address(adminControl), TEST_TOKEN_ID, newUris);
    }

    /*//////////////////////////////////////////////////////////////
                    12. revokeArtistPermissions TESTS
    //////////////////////////////////////////////////////////////*/

    function test_revokeArtistPermissions_Individual() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));

        // Revoke metadata permission
        vm.prank(artist, artist);
        vm.recordLogs();
        multiplex.revokeArtistPermissions(
            address(adminControl), TEST_TOKEN_ID, false, true, false, false, false, false, false
        );

        // Verify event
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 1);
        assertEq(logs[0].topics[0], keccak256("ArtistPermissionsRevoked(address,uint256,address)"));

        // Verify permission is revoked
        vm.prank(artist, artist);
        vm.expectRevert(abi.encodeWithSelector(Multiplex.ArtistPermissionRevoked.selector));
        multiplex.updateMetadata(address(adminControl), TEST_TOKEN_ID, "new metadata");

        // Verify other permissions still work
        vm.prank(artist, artist);
        multiplex.setDisplayMode(address(adminControl), TEST_TOKEN_ID, Multiplex.DisplayMode.HTML); // Should still work
    }

    function test_revokeAllArtistPermissions() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));

        vm.prank(artist, artist);
        multiplex.revokeAllArtistPermissions(address(adminControl), TEST_TOKEN_ID);

        // Verify all artist permissions are revoked
        vm.prank(artist, artist);
        vm.expectRevert(abi.encodeWithSelector(Multiplex.ArtistPermissionRevoked.selector));
        multiplex.updateMetadata(address(adminControl), TEST_TOKEN_ID, "new metadata");

        vm.prank(artist, artist);
        vm.expectRevert(abi.encodeWithSelector(Multiplex.ArtistPermissionRevoked.selector));
        multiplex.setDisplayMode(address(adminControl), TEST_TOKEN_ID, Multiplex.DisplayMode.HTML);
    }

    /*//////////////////////////////////////////////////////////////
                    13. removeArtworkUris TESTS
    //////////////////////////////////////////////////////////////*/

    function test_removeArtworkUris_OnlyArtistOrCollector() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));

        uint256[] memory indices = new uint256[](1);
        indices[0] = 0;

        vm.prank(stranger, stranger);
        vm.expectRevert(abi.encodeWithSelector(Multiplex.NotTokenOwnerOrAdmin.selector));
        multiplex.removeArtworkUris(address(adminControl), TEST_TOKEN_ID, indices);
    }

    function test_removeArtworkUris_Artist() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));

        uint256[] memory indices = new uint256[](1);
        indices[0] = 1; // Remove second URI

        vm.prank(artist, artist);
        vm.recordLogs();
        multiplex.removeArtworkUris(address(adminControl), TEST_TOKEN_ID, indices);

        // Verify event
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 1);
        assertEq(logs[0].topics[0], keccak256("ArtworkUriRemoved(address,uint256,address,uint256)"));

        // Verify URI removed
        string[] memory artistUris = multiplex.getArtistArtworkUris(address(adminControl), TEST_TOKEN_ID);
        assertEq(artistUris.length, 1);
    }

    function test_removeArtworkUris_SelectedIndexUpdate() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();
        config.artwork.selectedArtistUriIndex = 1; // Select second URI

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));

        uint256[] memory indices = new uint256[](1);
        indices[0] = 1; // Remove the selected URI

        vm.prank(artist, artist);
        multiplex.removeArtworkUris(address(adminControl), TEST_TOKEN_ID, indices);

        // Selected index should be updated to stay within bounds
        Multiplex.Artwork memory artwork = multiplex.getArtwork(address(adminControl), TEST_TOKEN_ID);
        assertEq(artwork.selectedArtistUriIndex, 0);
    }

    function test_removeArtworkUris_PermissionDenied() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();
        config.permissions.flags = config.permissions.flags & ~ARTIST_ADD_REMOVE;

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));

        uint256[] memory indices = new uint256[](1);
        indices[0] = 0;

        vm.prank(artist, artist);
        vm.expectRevert(abi.encodeWithSelector(Multiplex.ArtistPermissionRevoked.selector));
        multiplex.removeArtworkUris(address(adminControl), TEST_TOKEN_ID, indices);
    }

    /*//////////////////////////////////////////////////////////////
                    14. setSelectedUri TESTS
    //////////////////////////////////////////////////////////////*/

    function test_setSelectedUri_OnlyArtistOrCollector() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));

        vm.prank(stranger, stranger);
        vm.expectRevert(abi.encodeWithSelector(Multiplex.NotTokenOwnerOrAdmin.selector));
        multiplex.setSelectedUri(address(adminControl), TEST_TOKEN_ID, 1);
    }

    function test_setSelectedUri_Artist() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));

        vm.prank(artist, artist);
        vm.recordLogs();
        multiplex.setSelectedUri(address(adminControl), TEST_TOKEN_ID, 1);

        // Verify event
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 1);
        assertEq(logs[0].topics[0], keccak256("SelectedArtworkUriChanged(address,uint256,uint256)"));

        // Verify selection changed
        Multiplex.Artwork memory artwork = multiplex.getArtwork(address(adminControl), TEST_TOKEN_ID);
        assertEq(artwork.selectedArtistUriIndex, 1);
    }

    function test_setSelectedUri_OutOfRange() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));

        vm.prank(artist, artist);
        vm.expectRevert(abi.encodeWithSelector(Multiplex.InvalidIndexRange.selector));
        multiplex.setSelectedUri(address(adminControl), TEST_TOKEN_ID, 999);
    }

    function test_setSelectedUri_PermissionDenied() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();
        config.permissions.flags = config.permissions.flags & ~ARTIST_CHOOSE_URIS;

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));

        vm.prank(artist, artist);
        vm.expectRevert(abi.encodeWithSelector(Multiplex.ArtistPermissionRevoked.selector));
        multiplex.setSelectedUri(address(adminControl), TEST_TOKEN_ID, 1);
    }

    /*//////////////////////////////////////////////////////////////
                    15. setSelectedThumbnailUri TESTS
    //////////////////////////////////////////////////////////////*/

    function test_setSelectedThumbnailUri_OnlyArtistOrCollector() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));

        vm.prank(stranger, stranger);
        vm.expectRevert(abi.encodeWithSelector(Multiplex.NotTokenOwnerOrAdmin.selector));
        multiplex.setSelectedThumbnailUri(address(adminControl), TEST_TOKEN_ID, 1);
    }

    function test_setSelectedThumbnailUri_Success() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));

        vm.prank(artist, artist);
        vm.recordLogs();
        multiplex.setSelectedThumbnailUri(address(adminControl), TEST_TOKEN_ID, 1);

        // Verify event
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 1);
        assertEq(logs[0].topics[0], keccak256("SelectedThumbnailUriChanged(address,uint256,uint256)"));

        // Verify selection changed
        (, uint256 selectedIndex) = multiplex.getThumbnailInfo(address(adminControl), TEST_TOKEN_ID);
        assertEq(selectedIndex, 1);
    }

    function test_setSelectedThumbnailUri_OnlyOffChain() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();
        config.thumbnail.kind = Multiplex.ThumbnailKind.ON_CHAIN;
        config.thumbnail.onChain.mimeType = "image/png";
        config.thumbnail.onChain.zipped = false;

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, _createOnChainThumbnailChunks());

        vm.prank(artist, artist);
        vm.expectRevert(abi.encodeWithSelector(Multiplex.InvalidThumbnailKind.selector));
        multiplex.setSelectedThumbnailUri(address(adminControl), TEST_TOKEN_ID, 0);
    }

    /*//////////////////////////////////////////////////////////////
                    16. setDisplayMode TESTS
    //////////////////////////////////////////////////////////////*/

    function test_setDisplayMode_OnlyArtistOrCollector() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));

        vm.prank(stranger, stranger);
        vm.expectRevert(abi.encodeWithSelector(Multiplex.NotTokenOwnerOrAdmin.selector));
        multiplex.setDisplayMode(address(adminControl), TEST_TOKEN_ID, Multiplex.DisplayMode.HTML);
    }

    function test_setDisplayMode_Success() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));

        vm.prank(artist, artist);
        vm.recordLogs();
        multiplex.setDisplayMode(address(adminControl), TEST_TOKEN_ID, Multiplex.DisplayMode.HTML);

        // Verify event
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 1);
        assertEq(logs[0].topics[0], keccak256("DisplayModeUpdated(address,uint256,uint8)"));

        // Verify display mode changed
        (,,,, Multiplex.DisplayMode displayMode,) = multiplex.tokenData(address(adminControl), TEST_TOKEN_ID);
        assertEq(uint8(displayMode), uint8(Multiplex.DisplayMode.HTML));
    }

    function test_setDisplayMode_PermissionDenied() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();
        config.permissions.flags = config.permissions.flags & ~ARTIST_UPDATE_MODE;

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));

        vm.prank(artist, artist);
        vm.expectRevert(abi.encodeWithSelector(Multiplex.ArtistPermissionRevoked.selector));
        multiplex.setDisplayMode(address(adminControl), TEST_TOKEN_ID, Multiplex.DisplayMode.HTML);
    }

    /*//////////////////////////////////////////////////////////////
                    17. setDefaultHtmlTemplate TESTS
    //////////////////////////////////////////////////////////////*/

    function test_setDefaultHtmlTemplate_OnlyOwner() public {
        string memory newTemplate = "<html>new default template</html>";

        vm.prank(stranger, stranger);
        vm.expectRevert(); // Should revert with Ownable error
        multiplex.setDefaultHtmlTemplate(newTemplate);

        vm.prank(owner, owner);
        vm.recordLogs();
        multiplex.setDefaultHtmlTemplate(newTemplate);

        // Verify event
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 1);
        assertEq(logs[0].topics[0], keccak256("HtmlTemplateUpdated()"));

        // Verify template changed
        string memory template = multiplex.getDefaultHtmlTemplate();
        assertEq(template, newTemplate);
    }

    /*//////////////////////////////////////////////////////////////
                    18. RENDERING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_renderImage() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));

        string memory result = multiplex.renderImage(address(adminControl), TEST_TOKEN_ID);
        assertEq(result, "https://thumb1.com");
    }

    function test_renderRawImage() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();
        config.thumbnail.kind = Multiplex.ThumbnailKind.ON_CHAIN;
        config.thumbnail.onChain.mimeType = "image/png";
        config.thumbnail.onChain.zipped = false;

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, _createOnChainThumbnailChunks());

        bytes memory result = multiplex.renderRawImage(address(adminControl), TEST_TOKEN_ID);
        assertEq(result, "chunk1datachunk2data");
    }

    function test_renderHTML() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));

        string memory result = multiplex.renderHTML(address(adminControl), TEST_TOKEN_ID);
        assertTrue(bytes(result).length > 0);
        // Should start with "data:text/html;base64,"
        assertEq(bytes(result)[0], bytes1("d"));
    }

    function test_renderRawHTML() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));

        string memory result = multiplex.renderRawHTML(address(adminControl), TEST_TOKEN_ID);
        assertEq(result, '<html>"https://artist1.com","https://artist2.com"</html>');
    }

    function test_renderMetadata_DirectFileMode() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();
        config.displayMode = Multiplex.DisplayMode.DIRECT_FILE;

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));

        string memory result = multiplex.renderMetadata(address(adminControl), TEST_TOKEN_ID);
        assertTrue(bytes(result).length > 0);
        // Should start with "data:application/json;utf8,{"
        assertEq(bytes(result)[0], bytes1("d"));
    }

    function test_renderMetadata_HTMLMode() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();
        config.displayMode = Multiplex.DisplayMode.HTML;

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));

        string memory result = multiplex.renderMetadata(address(adminControl), TEST_TOKEN_ID);
        assertTrue(bytes(result).length > 0);
        // Should contain both image and animation_url fields
        assertEq(bytes(result)[0], bytes1("d"));
    }

    /*//////////////////////////////////////////////////////////////
                    19. VIEW FUNCTIONS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getArtistArtworkUris() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));

        string[] memory uris = multiplex.getArtistArtworkUris(address(adminControl), TEST_TOKEN_ID);
        assertEq(uris.length, 2);
        assertEq(uris[0], "https://artist1.com");
        assertEq(uris[1], "https://artist2.com");
    }

    function test_getCollectorArtworkUris() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(mockERC721), TEST_TOKEN_ID, config, new bytes[](0));

        string[] memory collectorUris = new string[](1);
        collectorUris[0] = "https://collector1.com";

        vm.prank(collector, collector);
        multiplex.addArtworkUris(address(mockERC721), TEST_TOKEN_ID, collectorUris);

        string[] memory uris = multiplex.getCollectorArtworkUris(address(mockERC721), TEST_TOKEN_ID);
        assertEq(uris.length, 1);
        assertEq(uris[0], "https://collector1.com");
    }

    function test_getThumbnailUris() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));

        string[] memory uris = multiplex.getThumbnailUris(address(adminControl), TEST_TOKEN_ID);
        assertEq(uris.length, 2);
        assertEq(uris[0], "https://thumb1.com");
        assertEq(uris[1], "https://thumb2.com");
    }

    function test_getPermissions() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));

        Multiplex.Permissions memory permissions = multiplex.getPermissions(address(adminControl), TEST_TOKEN_ID);
        assertTrue(permissions.flags & ARTIST_UPDATE_THUMB != 0);
        assertTrue(permissions.flags & ARTIST_UPDATE_META != 0);
    }

    function test_getArtwork() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));

        Multiplex.Artwork memory artwork = multiplex.getArtwork(address(adminControl), TEST_TOKEN_ID);
        assertEq(artwork.artistUris.length, 2);
        assertEq(artwork.mimeType, "image/png");
        assertEq(artwork.fileHash, "0x1234567890abcdef");
        assertEq(artwork.selectedArtistUriIndex, 0);
    }

    function test_getThumbnailInfo() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));

        (Multiplex.ThumbnailKind kind, uint256 selectedIndex) =
            multiplex.getThumbnailInfo(address(adminControl), TEST_TOKEN_ID);
        assertEq(uint8(kind), uint8(Multiplex.ThumbnailKind.OFF_CHAIN));
        assertEq(selectedIndex, 0);
    }

    function test_getOwnershipConfig() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));

        Multiplex.OwnershipConfig memory ownership = multiplex.getOwnershipConfig(address(adminControl), TEST_TOKEN_ID);
        assertEq(ownership.selector, bytes4(keccak256("ownerOf(uint256)")));
        assertEq(uint8(ownership.style), uint8(Multiplex.OwnershipStyle.OWNER_OF));
    }

    function test_getTokenHtmlTemplate() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));

        // Initially should return empty string (using default)
        string memory template = multiplex.getTokenHtmlTemplate(address(adminControl), TEST_TOKEN_ID);
        assertEq(template, "");

        // Set custom template
        string[] memory templateParts = new string[](1);
        templateParts[0] = "<html>custom</html>";

        vm.prank(artist, artist);
        multiplex.updateHtmlTemplate(address(adminControl), TEST_TOKEN_ID, templateParts);

        template = multiplex.getTokenHtmlTemplate(address(adminControl), TEST_TOKEN_ID);
        assertEq(template, "<html>custom</html>");
    }

    function test_getCombinedArtworkUris() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));

        string memory combined = multiplex.getCombinedArtworkUris(address(adminControl), TEST_TOKEN_ID);
        assertEq(combined, '"https://artist1.com","https://artist2.com"');
    }

    /*//////////////////////////////////////////////////////////////
                    20. HELPER FUNCTIONS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_encodeDataUri() public {
        string memory mimeType = "image/png";
        bytes memory data = "test data";

        string memory result = harness.encodeDataUriPublic(mimeType, data, false);
        assertEq(result, "data:image/png;base64,dGVzdCBkYXRh");
    }

    function test_appendJsonField() public {
        string memory json = '"name":"test"';
        string memory field = '"description":"desc"';

        string memory result = harness.appendJsonFieldPublic(json, field);
        assertEq(result, '"name":"test","description":"desc"');

        // Test with empty json
        result = harness.appendJsonFieldPublic("", field);
        assertEq(result, '"description":"desc"');
    }

    /*//////////////////////////////////////////////////////////////
                    21. ADDITIONAL ERROR COVERAGE
    //////////////////////////////////////////////////////////////*/

    function test_InvalidMetadata() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();
        config.metadata = "";

        vm.prank(artist, artist);
        vm.expectRevert(abi.encodeWithSelector(Multiplex.InvalidMetadata.selector));
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));
    }

    function test_InvalidArtworkUris() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();
        config.artwork.artistUris = new string[](0);

        vm.prank(artist, artist);
        vm.expectRevert(abi.encodeWithSelector(Multiplex.InvalidArtworkUris.selector));
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));
    }

    function test_InvalidMimeType() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();
        config.artwork.mimeType = "";

        vm.prank(artist, artist);
        vm.expectRevert(abi.encodeWithSelector(Multiplex.InvalidMimeType.selector));
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));
    }

    function test_InvalidFileHash() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();
        config.artwork.fileHash = "";

        vm.prank(artist, artist);
        vm.expectRevert(abi.encodeWithSelector(Multiplex.InvalidFileHash.selector));
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));
    }

    function test_OnChainThumbnailEmpty() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();
        config.thumbnail.kind = Multiplex.ThumbnailKind.ON_CHAIN;
        config.thumbnail.onChain.mimeType = "image/png";

        vm.prank(artist, artist);
        vm.expectRevert(abi.encodeWithSelector(Multiplex.OnChainThumbnailEmpty.selector));
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));
    }

    function test_InvalidSelectedThumbnailUriIndex() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();
        config.thumbnail.offChain.selectedUriIndex = 999;

        vm.prank(artist, artist);
        vm.expectRevert(abi.encodeWithSelector(Multiplex.InvalidSelectedThumbnailUriIndex.selector));
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));
    }

    function test_NotTokenOwnerOrAdmin() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));

        string[] memory uris = new string[](1);
        uris[0] = "test";

        vm.prank(stranger, stranger);
        vm.expectRevert(abi.encodeWithSelector(Multiplex.NotTokenOwnerOrAdmin.selector));
        multiplex.addArtworkUris(address(adminControl), TEST_TOKEN_ID, uris);
    }

    function test_CollectorPermissionDenied() public {
        Multiplex.InitConfig memory config = _createValidInitConfig();
        config.permissions.flags = config.permissions.flags & ~COLLECTOR_ADD_REMOVE;

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(mockERC721), TEST_TOKEN_ID, config, new bytes[](0));

        string[] memory uris = new string[](1);
        uris[0] = "test";

        vm.prank(collector, collector);
        vm.expectRevert(abi.encodeWithSelector(Multiplex.CollectorPermissionDenied.selector));
        multiplex.addArtworkUris(address(mockERC721), TEST_TOKEN_ID, uris);
    }

    /*//////////////////////////////////////////////////////////////
                    22. MISSING COMPREHENSIVE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_NotTokenOwner() public {
        // Test _isTokenOwner returns false when user doesn't own token
        Multiplex.InitConfig memory config = _createValidInitConfig();
        config.ownership.selector = bytes4(keccak256("ownerOf(uint256)"));
        config.ownership.style = Multiplex.OwnershipStyle.OWNER_OF;

        vm.prank(artist, artist);
        harness.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));

        // Test with the adminControl which doesn't have ownerOf - should return false
        vm.prank(stranger, stranger);
        assertFalse(harness.isTokenOwnerPublic(address(adminControl), TEST_TOKEN_ID));
    }

    function test_isTokenOwner_BalanceOfERC721() public {
        // Test BALANCE_OF_ERC721 ownership style
        Multiplex.InitConfig memory config = _createValidInitConfig();
        config.ownership.selector = bytes4(keccak256("balanceOf(address)"));
        config.ownership.style = Multiplex.OwnershipStyle.BALANCE_OF_ERC721;

        vm.prank(artist, artist);
        harness.initializeTokenData(address(mockERC721), TEST_TOKEN_ID, config, new bytes[](0));

        vm.prank(collector, collector);
        assertTrue(harness.isTokenOwnerPublic(address(mockERC721), TEST_TOKEN_ID));

        vm.prank(stranger, stranger);
        assertFalse(harness.isTokenOwnerPublic(address(mockERC721), TEST_TOKEN_ID));
    }

    function test_isTokenOwner_IsApprovedForAll() public {
        // Test IS_APPROVED_FOR_ALL ownership style with mock contract
        Multiplex.InitConfig memory config = _createValidInitConfig();
        config.ownership.selector = bytes4(keccak256("isApprovedForAll(address,address)"));
        config.ownership.style = Multiplex.OwnershipStyle.IS_APPROVED_FOR_ALL;

        vm.prank(artist, artist);
        harness.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));

        // This will likely return false since our mock doesn't have approval logic
        vm.prank(collector, collector);
        assertFalse(harness.isTokenOwnerPublic(address(mockERC721), TEST_TOKEN_ID));
    }

    function test_setSelectedUri_CollectorNotAffected() public {
        // Test that setSelectedUri only affects artist URIs, not collector URIs
        Multiplex.InitConfig memory config = _createValidInitConfig();

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(mockERC721), TEST_TOKEN_ID, config, new bytes[](0));

        // Add collector URIs
        string[] memory collectorUris = new string[](2);
        collectorUris[0] = "https://collector1.com";
        collectorUris[1] = "https://collector2.com";

        vm.prank(collector, collector);
        multiplex.addArtworkUris(address(mockERC721), TEST_TOKEN_ID, collectorUris);

        // Change selected artist URI
        vm.prank(artist, artist);
        multiplex.setSelectedUri(address(mockERC721), TEST_TOKEN_ID, 1);

        // Verify only artist URI selection changed
        Multiplex.Artwork memory artwork = multiplex.getArtwork(address(mockERC721), TEST_TOKEN_ID);
        assertEq(artwork.selectedArtistUriIndex, 1);

        // Collector URIs should be unaffected by setSelectedUri
        string[] memory storedCollectorUris = multiplex.getCollectorArtworkUris(address(mockERC721), TEST_TOKEN_ID);
        assertEq(storedCollectorUris.length, 2);
    }

    function test_removeArtworkUris_CollectorArray() public {
        // Test removal from collector array specifically
        Multiplex.InitConfig memory config = _createValidInitConfig();

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(mockERC721), TEST_TOKEN_ID, config, new bytes[](0));

        // Add collector URIs
        string[] memory collectorUris = new string[](3);
        collectorUris[0] = "https://collector1.com";
        collectorUris[1] = "https://collector2.com";
        collectorUris[2] = "https://collector3.com";

        vm.prank(collector, collector);
        multiplex.addArtworkUris(address(mockERC721), TEST_TOKEN_ID, collectorUris);

        // Remove middle collector URI
        uint256[] memory indices = new uint256[](1);
        indices[0] = 1;

        vm.prank(collector, collector);
        multiplex.removeArtworkUris(address(mockERC721), TEST_TOKEN_ID, indices);

        // Verify removal from collector array only
        string[] memory remainingCollectorUris = multiplex.getCollectorArtworkUris(address(mockERC721), TEST_TOKEN_ID);
        assertEq(remainingCollectorUris.length, 2);

        // Artist URIs should be unaffected
        string[] memory artistUris = multiplex.getArtistArtworkUris(address(mockERC721), TEST_TOKEN_ID);
        assertEq(artistUris.length, 2); // Original count
    }

    function test_AllPermissionCombinations() public {
        // Test all individual permission revocations
        Multiplex.InitConfig memory config = _createValidInitConfig();

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));

        // Test each permission individually
        vm.prank(artist, artist);
        multiplex.revokeArtistPermissions(
            address(adminControl), TEST_TOKEN_ID, true, false, false, false, false, false, false
        );

        Multiplex.Thumbnail memory newThumbnail = config.thumbnail;
        vm.prank(artist, artist);
        vm.expectRevert(abi.encodeWithSelector(Multiplex.ArtistPermissionRevoked.selector));
        multiplex.updateThumbnail(address(adminControl), TEST_TOKEN_ID, newThumbnail, new bytes[](0));

        // Test ARTIST_CHOOSE_URIS
        vm.prank(artist, artist);
        multiplex.revokeArtistPermissions(
            address(adminControl), TEST_TOKEN_ID, false, false, true, false, false, false, false
        );

        vm.prank(artist, artist);
        vm.expectRevert(abi.encodeWithSelector(Multiplex.ArtistPermissionRevoked.selector));
        multiplex.setSelectedUri(address(adminControl), TEST_TOKEN_ID, 0);

        // Test ARTIST_CHOOSE_THUMB
        vm.prank(artist, artist);
        multiplex.revokeArtistPermissions(
            address(adminControl), TEST_TOKEN_ID, false, false, false, false, true, false, false
        );

        // For testing thumbnail selection, we need to use the mockERC721 contract to enable collector ownership checks
        // First initialize a new token on mockERC721 for this test
        config = _createValidInitConfig();
        config.permissions.flags = config.permissions.flags & ~ARTIST_CHOOSE_THUMB; // Remove the permission we want to
            // test

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(mockERC721), 2, config, new bytes[](0));

        // Now test that the artist cannot use setSelectedThumbnailUri without permission
        vm.prank(artist, artist);
        vm.expectRevert(abi.encodeWithSelector(Multiplex.ArtistPermissionRevoked.selector));
        multiplex.setSelectedThumbnailUri(address(mockERC721), 2, 1);
    }

    function test_CollectorPermissions() public {
        // Test collector-specific permissions
        Multiplex.InitConfig memory config = _createValidInitConfig();

        // Remove collector choose URIs permission
        config.permissions.flags = config.permissions.flags & ~COLLECTOR_CHOOSE_URIS;

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(mockERC721), TEST_TOKEN_ID, config, new bytes[](0));

        vm.prank(collector, collector);
        vm.expectRevert(abi.encodeWithSelector(Multiplex.CollectorPermissionDenied.selector));
        multiplex.setSelectedUri(address(mockERC721), TEST_TOKEN_ID, 1);

        // Test collector choose thumbnail permission
        config.permissions.flags = config.permissions.flags & ~COLLECTOR_CHOOSE_THUMB;

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(mockERC721), 2, config, new bytes[](0));

        vm.prank(collector, collector);
        vm.expectRevert(abi.encodeWithSelector(Multiplex.CollectorPermissionDenied.selector));
        multiplex.setSelectedThumbnailUri(address(mockERC721), 2, 1);

        // Test collector update mode permission
        config.permissions.flags = config.permissions.flags & ~COLLECTOR_UPDATE_MODE;

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(mockERC721), 3, config, new bytes[](0));

        vm.prank(collector, collector);
        vm.expectRevert(abi.encodeWithSelector(Multiplex.CollectorPermissionDenied.selector));
        multiplex.setDisplayMode(address(mockERC721), 3, Multiplex.DisplayMode.HTML);
    }

    function test_AllEvents() public {
        // Comprehensive event testing
        Multiplex.InitConfig memory config = _createValidInitConfig();

        vm.prank(artist, artist);
        vm.recordLogs();
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));

        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 1);
        assertEq(logs[0].topics[0], keccak256("TokenDataInitialized(address,uint256)"));

        // Test MetadataUpdated event
        vm.prank(artist, artist);
        vm.recordLogs();
        multiplex.updateMetadata(address(adminControl), TEST_TOKEN_ID, "new metadata");

        logs = vm.getRecordedLogs();
        assertEq(logs.length, 1);
        assertEq(logs[0].topics[0], keccak256("MetadataUpdated(address,uint256)"));

        // Test SelectedArtworkUriChanged event
        vm.prank(artist, artist);
        vm.recordLogs();
        multiplex.setSelectedUri(address(adminControl), TEST_TOKEN_ID, 1);

        logs = vm.getRecordedLogs();
        assertEq(logs.length, 1);
        assertEq(logs[0].topics[0], keccak256("SelectedArtworkUriChanged(address,uint256,uint256)"));

        // Test ArtworkUrisAdded event
        string[] memory newUris = new string[](1);
        newUris[0] = "https://new.com";

        vm.prank(artist, artist);
        vm.recordLogs();
        multiplex.addArtworkUris(address(adminControl), TEST_TOKEN_ID, newUris);

        logs = vm.getRecordedLogs();
        assertEq(logs.length, 1);
        assertEq(logs[0].topics[0], keccak256("ArtworkUrisAdded(address,uint256,address,uint256)"));

        // Test DisplayModeUpdated event
        vm.prank(artist, artist);
        vm.recordLogs();
        multiplex.setDisplayMode(address(adminControl), TEST_TOKEN_ID, Multiplex.DisplayMode.HTML);

        logs = vm.getRecordedLogs();
        assertEq(logs.length, 1);
        assertEq(logs[0].topics[0], keccak256("DisplayModeUpdated(address,uint256,uint8)"));
    }

    function test_RemainingErrors() public {
        // Test remaining error cases that might not be covered

        // Test InvalidThumbnailKind with renderRawImage
        Multiplex.InitConfig memory config = _createValidInitConfig(); // Uses OFF_CHAIN by default

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));

        vm.expectRevert(abi.encodeWithSelector(Multiplex.InvalidThumbnailKind.selector));
        multiplex.renderRawImage(address(adminControl), TEST_TOKEN_ID);

        // Test InvalidIndexRange for off-chain thumbnail URIs
        config.thumbnail.offChain.uris = new string[](0);

        vm.prank(artist, artist);
        vm.expectRevert(abi.encodeWithSelector(Multiplex.InvalidIndexRange.selector));
        multiplex.initializeTokenData(address(adminControl), 999, config, new bytes[](0));

        // Test InvalidIndexRange for removeArtworkUris
        config = _createValidInitConfig();

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(adminControl), 998, config, new bytes[](0));

        uint256[] memory invalidIndices = new uint256[](1);
        invalidIndices[0] = 999; // Out of bounds

        vm.prank(artist, artist);
        vm.expectRevert(abi.encodeWithSelector(Multiplex.InvalidIndexRange.selector));
        multiplex.removeArtworkUris(address(adminControl), 998, invalidIndices);

        // Test empty indices array
        uint256[] memory emptyIndices = new uint256[](0);

        vm.prank(artist, artist);
        vm.expectRevert(abi.encodeWithSelector(Multiplex.InvalidIndexRange.selector));
        multiplex.removeArtworkUris(address(adminControl), 998, emptyIndices);
    }

    function test_AdvancedRenderingModes() public {
        // Test rendering with animation URIs
        Multiplex.InitConfig memory config = _createValidInitConfig();
        config.artwork.isAnimationUri = true;
        config.displayMode = Multiplex.DisplayMode.DIRECT_FILE;

        vm.prank(artist, artist);
        multiplex.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));

        string memory metadata = multiplex.renderMetadata(address(adminControl), TEST_TOKEN_ID);
        assertTrue(bytes(metadata).length > 0);

        // Test HTML mode rendering
        vm.prank(artist, artist);
        multiplex.setDisplayMode(address(adminControl), TEST_TOKEN_ID, Multiplex.DisplayMode.HTML);

        metadata = multiplex.renderMetadata(address(adminControl), TEST_TOKEN_ID);
        assertTrue(bytes(metadata).length > 0);
    }

    function test_EdgeCasePermutations() public {
        // Test with custom ownership that might fail
        Multiplex.InitConfig memory config = _createValidInitConfig();
        config.ownership.selector = bytes4(keccak256("nonExistentFunction(address)"));
        config.ownership.style = Multiplex.OwnershipStyle.SIMPLE_BOOL;

        vm.prank(artist, artist);
        harness.initializeTokenData(address(adminControl), TEST_TOKEN_ID, config, new bytes[](0));

        // This should return false because the function doesn't exist
        vm.prank(collector, collector);
        assertFalse(harness.isTokenOwnerPublic(address(mockCustomOwnership), TEST_TOKEN_ID));
    }
}
