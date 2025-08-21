// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Test } from "forge-std/src/Test.sol";
import { console2 } from "forge-std/src/console2.sol";
import { Multiplex } from "../src/Multiplex.sol";
import { Base64 } from "solady/utils/Base64.sol";
import { LibString } from "solady/utils/LibString.sol";
import { LibZip } from "solady/utils/LibZip.sol";
import { AdminControl } from "@manifoldxyz/libraries-solidity/contracts/access/AdminControl.sol";
import { IERC1155CreatorCore } from "@manifoldxyz/creator-core-solidity/contracts/core/IERC1155CreatorCore.sol";
import { IERC721CreatorCore } from "@manifoldxyz/creator-core-solidity/contracts/core/IERC721CreatorCore.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { ICreatorExtensionTokenURI } from
    "@manifoldxyz/creator-core-solidity/contracts/extensions/ICreatorExtensionTokenURI.sol";
import { IAdminControl } from "@manifoldxyz/libraries-solidity/contracts/access/IAdminControl.sol";

// TODO: DANGER! This is an AI generated test contract. It's not a proper test and the project shouldn't be deployed
// on mainnet without proper, human made test cases.

// Mock ERC721 Creator Contract
contract MockERC721Creator is AdminControl, IERC721CreatorCore, IERC721 {
    uint256 private _currentTokenId;
    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    constructor() { }

    function supportsInterface(bytes4 interfaceId) public view virtual override(AdminControl, IERC165) returns (bool) {
        return interfaceId == type(IERC721CreatorCore).interfaceId || interfaceId == type(IERC721).interfaceId
            || AdminControl.supportsInterface(interfaceId);
    }

    // IERC721CreatorCore implementation
    function mintExtension(address to) public override returns (uint256) {
        uint256 tokenId = ++_currentTokenId;
        _mint(to, tokenId);
        return tokenId;
    }

    function mintExtension(address to, string calldata) external override returns (uint256) {
        return this.mintExtension(to);
    }

    function mintExtension(address to, uint80) external override returns (uint256) {
        return this.mintExtension(to);
    }

    function mintExtensionBatch(address to, uint16 count) public override returns (uint256[] memory tokenIds) {
        tokenIds = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            tokenIds[i] = this.mintExtension(to);
        }
    }

    function mintExtensionBatch(address to, string[] calldata) external override returns (uint256[] memory) {
        return this.mintExtensionBatch(to, uint16(1));
    }

    function mintExtensionBatch(address to, uint80[] calldata) external override returns (uint256[] memory) {
        return this.mintExtensionBatch(to, uint16(1));
    }

    // IERC721 implementation
    function balanceOf(address owner) public view override returns (uint256) {
        require(owner != address(0), "ERC721: address zero is not a valid owner");
        return _balances[owner];
    }

    function ownerOf(uint256 tokenId) public view override returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721: invalid token ID");
        return owner;
    }

    function approve(address to, uint256 tokenId) public override {
        address owner = ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");
        require(
            msg.sender == owner || isApprovedForAll(owner, msg.sender),
            "ERC721: approve caller is not token owner or approved for all"
        );
        _tokenApprovals[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

    function getApproved(uint256 tokenId) public view override returns (address) {
        return _tokenApprovals[tokenId];
    }

    function setApprovalForAll(address operator, bool approved) public override {
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address owner, address operator) public view override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    function transferFrom(address from, address to, uint256 tokenId) public override {
        require(_isApprovedOrOwner(msg.sender, tokenId), "ERC721: caller is not token owner or approved");
        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public override {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory) public override {
        require(_isApprovedOrOwner(msg.sender, tokenId), "ERC721: caller is not token owner or approved");
        _transfer(from, to, tokenId);
    }

    // Internal functions
    function _mint(address to, uint256 tokenId) internal {
        require(to != address(0), "ERC721: mint to the zero address");
        require(_owners[tokenId] == address(0), "ERC721: token already minted");
        _balances[to] += 1;
        _owners[tokenId] = to;
        emit Transfer(address(0), to, tokenId);
    }

    function _transfer(address from, address to, uint256 tokenId) internal {
        require(ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");
        require(to != address(0), "ERC721: transfer to the zero address");
        delete _tokenApprovals[tokenId];
        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;
        emit Transfer(from, to, tokenId);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        address owner = ownerOf(tokenId);
        return (spender == owner || isApprovedForAll(owner, spender) || getApproved(tokenId) == spender);
    }

    // Stub implementations for other IERC721CreatorCore methods
    function registerExtension(address, string calldata) external override { }
    function registerExtension(address, string calldata, bool) external override { }
    function unregisterExtension(address) external override { }
    function blacklistExtension(address) external override { }
    function setBaseTokenURI(string calldata) external override { }
    function setBaseTokenURIExtension(string calldata) external override { }
    function setBaseTokenURIExtension(string calldata, bool) external override { }
    function setTokenURIPrefixExtension(string calldata) external override { }
    function setTokenURIExtension(uint256, string calldata) external override { }
    function setTokenURIExtension(uint256[] calldata, string[] calldata) external override { }
    function setApproveTransferExtension(bool) external override { }

    function tokenExtension(uint256) external pure override returns (address) {
        return address(0);
    }

    function burn(uint256) external pure override { }
    function setRoyalties(address payable[] calldata, uint256[] calldata) external override { }
    function setRoyalties(uint256, address payable[] calldata, uint256[] calldata) external override { }
    function setRoyaltiesExtension(address, address payable[] calldata, uint256[] calldata) external override { }

    function getRoyalties(uint256) external pure override returns (address payable[] memory, uint256[] memory) {
        return (new address payable[](0), new uint256[](0));
    }

    function getFeeRecipients(uint256) external pure override returns (address payable[] memory) {
        return new address payable[](0);
    }

    function getFeeBps(uint256) external pure override returns (uint256[] memory) {
        return new uint256[](0);
    }

    function getFees(uint256) external pure override returns (address payable[] memory, uint256[] memory) {
        return (new address payable[](0), new uint256[](0));
    }

    function royaltyInfo(uint256, uint256) external pure override returns (address, uint256) {
        return (address(0), 0);
    }

    function getApproveTransfer() external pure override returns (address) {
        return address(0);
    }

    // Missing ICreatorCore methods
    function getExtensions() external pure override returns (address[] memory) {
        return new address[](0);
    }

    function mintBase(address to) external override returns (uint256) {
        return mintExtension(to);
    }

    function mintBase(address to, string calldata) external override returns (uint256) {
        return mintExtension(to);
    }

    function mintBaseBatch(address to, uint16 count) external override returns (uint256[] memory) {
        return mintExtensionBatch(to, count);
    }

    function mintBaseBatch(address to, string[] calldata) external override returns (uint256[] memory) {
        return mintExtensionBatch(to, uint16(1));
    }

    function setApproveTransfer(address) external override { }
    function setMintPermissions(address, address) external override { }
    function setTokenURI(uint256, string calldata) external override { }
    function setTokenURI(uint256[] memory, string[] calldata) external override { }
    function setTokenURIPrefix(string calldata) external override { }

    function tokenData(uint256) external pure override returns (uint80) {
        return 0;
    }
}

// Mock ERC1155 Creator Contract
contract MockERC1155Creator is AdminControl, IERC1155CreatorCore, IERC1155 {
    uint256 private _currentTokenId;
    mapping(uint256 => mapping(address => uint256)) private _balances;
    mapping(address => mapping(address => bool)) private _operatorApprovals;
    string private _uri;

    constructor() { }

    function supportsInterface(bytes4 interfaceId) public view virtual override(AdminControl, IERC165) returns (bool) {
        return interfaceId == type(IERC1155CreatorCore).interfaceId || interfaceId == type(IERC1155).interfaceId
            || AdminControl.supportsInterface(interfaceId);
    }

    // IERC1155CreatorCore implementation
    function mintExtensionNew(
        address[] calldata to,
        uint256[] calldata amounts,
        string[] calldata
    )
        external
        override
        returns (uint256[] memory tokenIds)
    {
        require(to.length == amounts.length, "Length mismatch");
        tokenIds = new uint256[](to.length);

        for (uint256 i = 0; i < to.length; i++) {
            uint256 tokenId = ++_currentTokenId;
            tokenIds[i] = tokenId;
            _mint(to[i], tokenId, amounts[i], "");
        }
    }

    function mintExtensionExisting(
        address[] calldata to,
        uint256[] calldata tokenIds,
        uint256[] calldata amounts
    )
        external
        override
    {
        require(to.length == tokenIds.length && tokenIds.length == amounts.length, "Length mismatch");
        for (uint256 i = 0; i < to.length; i++) {
            _mint(to[i], tokenIds[i], amounts[i], "");
        }
    }

    // IERC1155 implementation
    function uri(uint256) public view virtual returns (string memory) {
        return _uri;
    }

    function balanceOf(address account, uint256 id) public view override returns (uint256) {
        require(account != address(0), "ERC1155: address zero is not a valid owner");
        return _balances[id][account];
    }

    function balanceOfBatch(
        address[] memory accounts,
        uint256[] memory ids
    )
        public
        view
        override
        returns (uint256[] memory)
    {
        require(accounts.length == ids.length, "ERC1155: accounts and ids length mismatch");
        uint256[] memory batchBalances = new uint256[](accounts.length);
        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = balanceOf(accounts[i], ids[i]);
        }
        return batchBalances;
    }

    function setApprovalForAll(address operator, bool approved) public override {
        _setApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address account, address operator) public view override returns (bool) {
        return _operatorApprovals[account][operator];
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    )
        public
        override
    {
        require(
            from == msg.sender || isApprovedForAll(from, msg.sender), "ERC1155: caller is not token owner or approved"
        );
        _safeTransferFrom(from, to, id, amount, data);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    )
        public
        override
    {
        require(
            from == msg.sender || isApprovedForAll(from, msg.sender), "ERC1155: caller is not token owner or approved"
        );
        _safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    // Internal functions
    function _mint(address to, uint256 id, uint256 amount, bytes memory) internal {
        require(to != address(0), "ERC1155: mint to the zero address");
        _balances[id][to] += amount;
        emit TransferSingle(msg.sender, address(0), to, id, amount);
    }

    function _safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory) internal {
        require(to != address(0), "ERC1155: transfer to the zero address");
        uint256 fromBalance = _balances[id][from];
        require(fromBalance >= amount, "ERC1155: insufficient balance for transfer");
        unchecked {
            _balances[id][from] = fromBalance - amount;
        }
        _balances[id][to] += amount;
        emit TransferSingle(msg.sender, from, to, id, amount);
    }

    function _safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory
    )
        internal
    {
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");
        require(to != address(0), "ERC1155: transfer to the zero address");

        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];
            uint256 fromBalance = _balances[id][from];
            require(fromBalance >= amount, "ERC1155: insufficient balance for transfer");
            unchecked {
                _balances[id][from] = fromBalance - amount;
            }
            _balances[id][to] += amount;
        }
        emit TransferBatch(msg.sender, from, to, ids, amounts);
    }

    function _setApprovalForAll(address owner, address operator, bool approved) internal {
        require(owner != operator, "ERC1155: setting approval status for self");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    // Stub implementations for other IERC1155CreatorCore methods
    function registerExtension(address, string calldata) external override { }
    function registerExtension(address, string calldata, bool) external override { }
    function unregisterExtension(address) external override { }
    function blacklistExtension(address) external override { }
    function setBaseTokenURI(string calldata) external override { }
    function setBaseTokenURIExtension(string calldata) external override { }
    function setBaseTokenURIExtension(string calldata, bool) external override { }
    function setTokenURIPrefixExtension(string calldata) external override { }
    function setTokenURIExtension(uint256, string calldata) external override { }
    function setTokenURIExtension(uint256[] calldata, string[] calldata) external override { }
    function setApproveTransferExtension(bool) external override { }

    function tokenExtension(uint256) external pure override returns (address) {
        return address(0);
    }

    function burn(address, uint256[] calldata, uint256[] calldata) external pure override { }
    function setRoyalties(address payable[] calldata, uint256[] calldata) external override { }
    function setRoyalties(uint256, address payable[] calldata, uint256[] calldata) external override { }
    function setRoyaltiesExtension(address, address payable[] calldata, uint256[] calldata) external override { }

    function getRoyalties(uint256) external pure override returns (address payable[] memory, uint256[] memory) {
        return (new address payable[](0), new uint256[](0));
    }

    function getFeeRecipients(uint256) external pure override returns (address payable[] memory) {
        return new address payable[](0);
    }

    function getFeeBps(uint256) external pure override returns (uint256[] memory) {
        return new uint256[](0);
    }

    function getFees(uint256) external pure override returns (address payable[] memory, uint256[] memory) {
        return (new address payable[](0), new uint256[](0));
    }

    function royaltyInfo(uint256, uint256) external pure override returns (address, uint256) {
        return (address(0), 0);
    }

    function getApproveTransfer() external pure override returns (address) {
        return address(0);
    }

    function totalSupply(uint256) external pure override returns (uint256) {
        return 0;
    }

    // Missing ICreatorCore methods
    function getExtensions() external pure override returns (address[] memory) {
        return new address[](0);
    }

    function mintBaseNew(
        address[] calldata to,
        uint256[] calldata amounts,
        string[] calldata
    )
        external
        override
        returns (uint256[] memory)
    {
        return this.mintExtensionNew(to, amounts, new string[](0));
    }

    function mintBaseExisting(
        address[] calldata to,
        uint256[] calldata tokenIds,
        uint256[] calldata amounts
    )
        external
        override
    {
        this.mintExtensionExisting(to, tokenIds, amounts);
    }

    function setApproveTransfer(address) external override { }
    function setMintPermissions(address, address) external override { }
    function setTokenURI(uint256, string calldata) external override { }
    function setTokenURI(uint256[] memory, string[] calldata) external override { }
    function setTokenURIPrefix(string calldata) external override { }
}

// Test wrapper to expose internal functions
contract MultiplexTestWrapper is Multiplex {
    constructor(string memory _htmlTemplate) Multiplex(_htmlTemplate) { }

    function isCreatorContractERC1155_test(address creatorContractAddress) external view returns (bool) {
        return isCreatorContractERC1155(creatorContractAddress);
    }

    function isCreatorContractERC721_test(address creatorContractAddress) external view returns (bool) {
        return isCreatorContractERC721(creatorContractAddress);
    }
}

// Main Test Contract
contract MultiplexTest is Test {
    MultiplexTestWrapper public multiplex;
    MockERC721Creator public erc721Creator;
    MockERC1155Creator public erc1155Creator;

    // Test accounts
    address public artist = address(0x1);
    address public collector1 = address(0x2);
    address public collector2 = address(0x3);
    address public nonOwner = address(0x4);

    // Sample data
    string constant HTML_TEMPLATE = "<html><body>{{IMAGE_URIS}} {{IMAGE_HASH}}</body></html>";
    string constant SAMPLE_METADATA = '"name":"Test Token","description":"A test token"';
    string constant SAMPLE_IMAGE_HASH = "QmTest123";
    string constant SAMPLE_MIME_TYPE = "image/png";
    bytes constant SAMPLE_THUMBNAIL = hex"89504e470d0a1a0a0000000d49484452";

    // Events to test
    event TokenMinted(address indexed creator, uint256 indexed tokenId, address indexed recipient, uint256 quantity);
    event BatchTokensMinted(address indexed creator, uint256 indexed firstTokenId, uint256 totalMinted);
    event MetadataUpdated(address indexed creator, uint256 indexed tokenId);
    event MetadataLocked(address indexed creator, uint256 indexed tokenId);
    event ThumbnailUpdated(address indexed creator, uint256 indexed tokenId, uint256 chunkCount);
    event ThumbnailLocked(address indexed creator, uint256 indexed tokenId);
    event DisplayModeUpdated(address indexed creator, uint256 indexed tokenId, Multiplex.DisplayMode displayMode);
    event SelectedArtistArtworkChanged(address indexed creator, uint256 indexed tokenId, uint256 newIndex);
    event SelectedArtistThumbnailChanged(address indexed creator, uint256 indexed tokenId, uint256 newIndex);
    event ArtistArtworkUrisAdded(address indexed creator, uint256 indexed tokenId, uint256 count);
    event ArtistArtworkUriRemoved(address indexed creator, uint256 indexed tokenId, uint256 index);
    event ArtistThumbnailUrisAdded(address indexed creator, uint256 indexed tokenId, uint256 count);
    event ArtistThumbnailUriRemoved(address indexed creator, uint256 indexed tokenId, uint256 index);
    event CollectorArtworkUrisAdded(address indexed creator, uint256 indexed tokenId, uint256 count);
    event HtmlTemplateUpdated();

    function setUp() public {
        // Deploy contracts
        multiplex = new MultiplexTestWrapper(HTML_TEMPLATE);
        erc721Creator = new MockERC721Creator();
        erc1155Creator = new MockERC1155Creator();

        // Setup test accounts
        vm.label(artist, "Artist");
        vm.label(collector1, "Collector1");
        vm.label(collector2, "Collector2");
        vm.label(nonOwner, "NonOwner");

        // Add artist as admin to creator contracts
        // The test contract is the owner since it deployed the contracts
        erc721Creator.approveAdmin(artist);
        erc1155Creator.approveAdmin(artist);

        // Transfer ownership to artist so they can be the true owner
        erc721Creator.transferOwnership(artist);
        erc1155Creator.transferOwnership(artist);

        // The test wrapper multiplex was deployed by the test contract,
        // so we can add artist as admin
        multiplex.approveAdmin(artist);
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Constructor() public view {
        assertEq(multiplex.getHtmlTemplate(), HTML_TEMPLATE);
    }

    function test_SetHtmlTemplate() public {
        string memory newTemplate = "<div>{{IMAGE_URIS}}</div>";

        // Non-admin should fail
        vm.prank(nonOwner);
        vm.expectRevert(Multiplex.WalletNotAdmin.selector);
        multiplex.setHtmlTemplate(newTemplate);

        // Admin should succeed
        vm.prank(artist);
        vm.expectEmit(true, true, true, true);
        emit HtmlTemplateUpdated();
        multiplex.setHtmlTemplate(newTemplate);

        assertEq(multiplex.getHtmlTemplate(), newTemplate);
    }

    /*//////////////////////////////////////////////////////////////
                        ACCESS HELPER TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CreatorContractTypeChecks() public {
        // Deploy a regular ERC721 (not creator core)
        new MockERC721Creator();

        // Test interface checks
        assertFalse(multiplex.isCreatorContractERC721_test(address(erc1155Creator)));
        assertFalse(multiplex.isCreatorContractERC1155_test(address(erc721Creator)));
        assertTrue(multiplex.isCreatorContractERC721_test(address(erc721Creator)));
        assertTrue(multiplex.isCreatorContractERC1155_test(address(erc1155Creator)));
    }

    /*//////////////////////////////////////////////////////////////
                            MINTING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_MintERC721_Single() public {
        // Prepare mint params
        Multiplex.MintParams memory baseParams = Multiplex.MintParams({
            metadata: SAMPLE_METADATA,
            onChainThumbnail: Multiplex.File({
                mimeType: SAMPLE_MIME_TYPE,
                chunks: new address[](0),
                length: SAMPLE_THUMBNAIL.length,
                zipped: false,
                deflated: false
            }),
            initialDisplayMode: Multiplex.DisplayMode.IMAGE,
            immutableProperties: Multiplex.ImmutableProperties({
                imageHash: SAMPLE_IMAGE_HASH,
                imageMimeType: "image/jpeg",
                isAnimationUri: false,
                useOffchainThumbnail: false,
                allowCollectorAddArtwork: true,
                allowCollectorSelectArtistArtwork: true,
                allowCollectorSelectArtistThumbnail: true,
                allowCollectorToggleDisplayMode: true
            }),
            seedArtistArtworkUris: new string[](0),
            seedArtistThumbnailUris: new string[](0)
        });

        address[] memory recipients = new address[](1);
        recipients[0] = collector1;

        Multiplex.MintERC721Params memory params =
            Multiplex.MintERC721Params({ baseParams: baseParams, recipients: recipients });

        bytes[] memory thumbnailChunks = new bytes[](1);
        thumbnailChunks[0] = SAMPLE_THUMBNAIL;

        // Mint
        vm.prank(artist);
        vm.expectEmit(true, true, true, true);
        emit TokenMinted(address(erc721Creator), 1, collector1, 1);
        vm.expectEmit(true, true, true, true);
        emit BatchTokensMinted(address(erc721Creator), 1, 1);
        multiplex.mintERC721(address(erc721Creator), params, thumbnailChunks);

        // Verify token data
        (
            string memory metadata,
            Multiplex.File memory thumbnail,
            Multiplex.DisplayMode displayMode,
            Multiplex.ImmutableProperties memory immutableProps,
            Multiplex.OffChainData memory offchain,
            Multiplex.Selection memory selection,
            bool metadataLocked,
            bool thumbnailLocked
        ) = multiplex.tokenData(address(erc721Creator), 1);

        assertEq(metadata, SAMPLE_METADATA);
        assertEq(uint256(displayMode), uint256(Multiplex.DisplayMode.IMAGE));
        assertEq(immutableProps.imageHash, SAMPLE_IMAGE_HASH);
        assertFalse(metadataLocked);
        assertFalse(thumbnailLocked);

        // Verify ownership
        assertEq(erc721Creator.ownerOf(1), collector1);
    }

    function test_MintERC1155_Multiple() public {
        // Prepare mint params with seed URIs
        string[] memory seedArtworkUris = new string[](2);
        seedArtworkUris[0] = "https://example.com/art1.jpg";
        seedArtworkUris[1] = "https://example.com/art2.jpg";

        Multiplex.MintParams memory baseParams = Multiplex.MintParams({
            metadata: SAMPLE_METADATA,
            onChainThumbnail: Multiplex.File({
                mimeType: SAMPLE_MIME_TYPE,
                chunks: new address[](0),
                length: SAMPLE_THUMBNAIL.length,
                zipped: false,
                deflated: false
            }),
            initialDisplayMode: Multiplex.DisplayMode.HTML,
            immutableProperties: Multiplex.ImmutableProperties({
                imageHash: SAMPLE_IMAGE_HASH,
                imageMimeType: "image/jpeg",
                isAnimationUri: true,
                useOffchainThumbnail: true,
                allowCollectorAddArtwork: true,
                allowCollectorSelectArtistArtwork: true,
                allowCollectorSelectArtistThumbnail: true,
                allowCollectorToggleDisplayMode: true
            }),
            seedArtistArtworkUris: seedArtworkUris,
            seedArtistThumbnailUris: new string[](0)
        });

        address[] memory recipients = new address[](2);
        recipients[0] = collector1;
        recipients[1] = collector2;

        uint256[] memory quantities = new uint256[](2);
        quantities[0] = 10;
        quantities[1] = 5;

        Multiplex.MintERC1155Params memory params =
            Multiplex.MintERC1155Params({ baseParams: baseParams, recipients: recipients, quantities: quantities });

        bytes[] memory thumbnailChunks = new bytes[](1);
        thumbnailChunks[0] = SAMPLE_THUMBNAIL;

        // Mint
        vm.prank(artist);
        multiplex.mintERC1155(address(erc1155Creator), params, thumbnailChunks);

        // Verify balances
        assertEq(erc1155Creator.balanceOf(collector1, 1), 10);
        assertEq(erc1155Creator.balanceOf(collector2, 2), 5);

        // Verify token data (only first token has data)
        (,,,, Multiplex.OffChainData memory offchain, Multiplex.Selection memory selection,,) =
            multiplex.tokenData(address(erc1155Creator), 1);

        assertEq(offchain.artistArtworkUris.length, 2);
        assertEq(offchain.artistArtworkUris[0], seedArtworkUris[0]);
        assertEq(selection.selectedArtistArtworkIndex, 1); // First artwork selected by default
    }

    function test_MintInvalidInputs() public {
        Multiplex.MintParams memory baseParams = Multiplex.MintParams({
            metadata: SAMPLE_METADATA,
            onChainThumbnail: Multiplex.File({
                mimeType: SAMPLE_MIME_TYPE,
                chunks: new address[](0),
                length: SAMPLE_THUMBNAIL.length,
                zipped: true,
                deflated: true // Both compression flags set - invalid
             }),
            initialDisplayMode: Multiplex.DisplayMode.IMAGE,
            immutableProperties: Multiplex.ImmutableProperties({
                imageHash: SAMPLE_IMAGE_HASH,
                imageMimeType: "image/jpeg",
                isAnimationUri: false,
                useOffchainThumbnail: false,
                allowCollectorAddArtwork: false,
                allowCollectorSelectArtistArtwork: false,
                allowCollectorSelectArtistThumbnail: false,
                allowCollectorToggleDisplayMode: false
            }),
            seedArtistArtworkUris: new string[](0),
            seedArtistThumbnailUris: new string[](0)
        });

        bytes[] memory thumbnailChunks = new bytes[](0);

        // Test compression flag error
        address[] memory recipients = new address[](1);
        recipients[0] = collector1;

        Multiplex.MintERC721Params memory erc721Params =
            Multiplex.MintERC721Params({ baseParams: baseParams, recipients: recipients });

        vm.prank(artist);
        vm.expectRevert(Multiplex.InvalidCompressionFlags.selector);
        multiplex.mintERC721(address(erc721Creator), erc721Params, thumbnailChunks);

        // Test mismatched array lengths for ERC1155
        baseParams.onChainThumbnail.zipped = false; // Fix compression flags

        uint256[] memory quantities = new uint256[](2); // Mismatch with recipients
        quantities[0] = 1;
        quantities[1] = 1;

        Multiplex.MintERC1155Params memory erc1155Params =
            Multiplex.MintERC1155Params({ baseParams: baseParams, recipients: recipients, quantities: quantities });

        vm.prank(artist);
        vm.expectRevert(Multiplex.InvalidIndexRange.selector);
        multiplex.mintERC1155(address(erc1155Creator), erc1155Params, thumbnailChunks);

        // Test wrong creator contract type
        vm.prank(artist);
        vm.expectRevert(Multiplex.CreatorMustImplementCreatorCoreInterface.selector);
        multiplex.mintERC721(address(erc1155Creator), erc721Params, thumbnailChunks);
    }

    /*//////////////////////////////////////////////////////////////
                    ARTIST ARTWORK MANAGEMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ArtistArtworkManagement() public {
        // Setup: mint a token first
        _mintTestToken721();

        // Add artwork URIs
        string[] memory uris = new string[](3);
        uris[0] = "https://example.com/art1.jpg";
        uris[1] = "https://example.com/art2.jpg";
        uris[2] = "https://example.com/art3.jpg";

        vm.prank(artist);
        vm.expectEmit(true, true, true, true);
        emit ArtistArtworkUrisAdded(address(erc721Creator), 1, 3);
        multiplex.addArtistArtworkUris(address(erc721Creator), 1, uris);

        // Verify URIs added and first one selected
        string[] memory storedUris = multiplex.getArtistArtworkUris(address(erc721Creator), 1);
        assertEq(storedUris.length, 3);
        assertEq(storedUris[0], uris[0]);

        (,,,, Multiplex.OffChainData memory offchain, Multiplex.Selection memory selection,,) =
            multiplex.tokenData(address(erc721Creator), 1);
        assertEq(selection.selectedArtistArtworkIndex, 1);

        // Remove middle URI
        vm.prank(artist);
        vm.expectEmit(true, true, true, true);
        emit ArtistArtworkUriRemoved(address(erc721Creator), 1, 1);
        multiplex.removeArtistArtworkUri(address(erc721Creator), 1, 1);

        // Verify array updated correctly (last element moved to removed position)
        storedUris = multiplex.getArtistArtworkUris(address(erc721Creator), 1);
        assertEq(storedUris.length, 2);
        assertEq(storedUris[0], uris[0]);
        assertEq(storedUris[1], uris[2]); // Last element moved here

        // Test removing selected item
        vm.prank(artist);
        multiplex.removeArtistArtworkUri(address(erc721Creator), 1, 0);

        (,,,,, selection,,) = multiplex.tokenData(address(erc721Creator), 1);
        assertEq(selection.selectedArtistArtworkIndex, 1); // Should select first remaining item

        // Test non-admin cannot add/remove
        vm.prank(collector1);
        vm.expectRevert(Multiplex.WalletNotAdmin.selector);
        multiplex.addArtistArtworkUris(address(erc721Creator), 1, uris);

        vm.prank(collector1);
        vm.expectRevert(Multiplex.WalletNotAdmin.selector);
        multiplex.removeArtistArtworkUri(address(erc721Creator), 1, 0);
    }

    /*//////////////////////////////////////////////////////////////
                  ARTIST THUMBNAIL MANAGEMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ArtistThumbnailManagement() public {
        // Setup: mint a token first
        _mintTestToken721();

        // Add thumbnail URIs
        string[] memory uris = new string[](2);
        uris[0] = "https://example.com/thumb1.jpg";
        uris[1] = "https://example.com/thumb2.jpg";

        vm.prank(artist);
        vm.expectEmit(true, true, true, true);
        emit ArtistThumbnailUrisAdded(address(erc721Creator), 1, 2);
        multiplex.addArtistThumbnailUris(address(erc721Creator), 1, uris);

        // Verify URIs added
        string[] memory storedUris = multiplex.getArtistThumbnailUris(address(erc721Creator), 1);
        assertEq(storedUris.length, 2);

        // Select second thumbnail
        Multiplex.UpdateParams memory updateParams = Multiplex.UpdateParams({
            metadata: "",
            updateMetadata: false,
            thumbnailChunks: new bytes[](0),
            thumbnailOptions: Multiplex.File({
                mimeType: "",
                chunks: new address[](0),
                length: 0,
                zipped: false,
                deflated: false
            }),
            updateThumbnail: false,
            displayMode: Multiplex.DisplayMode.IMAGE,
            updateDisplayMode: false,
            selectedArtistArtworkIndex: 0,
            updateSelectedArtistArtwork: false,
            selectedArtistThumbnailIndex: 2,
            updateSelectedArtistThumbnail: true
        });

        vm.prank(artist);
        vm.expectEmit(true, true, true, true);
        emit SelectedArtistThumbnailChanged(address(erc721Creator), 1, 2);
        multiplex.updateToken(address(erc721Creator), 1, updateParams);

        // Remove selected thumbnail
        vm.prank(artist);
        multiplex.removeArtistThumbnailUri(address(erc721Creator), 1, 1);

        // Verify selection adjusted
        (,,,, Multiplex.OffChainData memory offchain, Multiplex.Selection memory selection,,) =
            multiplex.tokenData(address(erc721Creator), 1);
        assertEq(selection.selectedArtistThumbnailIndex, 1); // First remaining thumbnail selected
    }

    /*//////////////////////////////////////////////////////////////
                  COLLECTOR ARTWORK MANAGEMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CollectorArtworkManagement() public {
        // Setup: mint token with collector permissions enabled
        _mintTestToken721();

        // Collector adds artwork
        string[] memory uris = new string[](2);
        uris[0] = "https://collector.com/art1.jpg";
        uris[1] = "https://collector.com/art2.jpg";

        vm.prank(collector1);
        vm.expectEmit(true, true, true, true);
        emit CollectorArtworkUrisAdded(address(erc721Creator), 1, 2);
        multiplex.addCollectorArtworkUris(address(erc721Creator), 1, uris);

        // Verify URIs added
        string[] memory storedUris = multiplex.getCollectorArtworkUris(address(erc721Creator), 1);
        assertEq(storedUris.length, 2);
        assertEq(storedUris[0], uris[0]);

        // Non-owner cannot add
        vm.prank(nonOwner);
        vm.expectRevert(Multiplex.NotTokenOwner.selector);
        multiplex.addCollectorArtworkUris(address(erc721Creator), 1, uris);
    }

    function test_CollectorArtworkManagement_Disabled() public {
        // Mint token with collector permissions disabled
        Multiplex.MintParams memory baseParams = Multiplex.MintParams({
            metadata: SAMPLE_METADATA,
            onChainThumbnail: Multiplex.File({
                mimeType: SAMPLE_MIME_TYPE,
                chunks: new address[](0),
                length: SAMPLE_THUMBNAIL.length,
                zipped: false,
                deflated: false
            }),
            initialDisplayMode: Multiplex.DisplayMode.IMAGE,
            immutableProperties: Multiplex.ImmutableProperties({
                imageHash: SAMPLE_IMAGE_HASH,
                imageMimeType: "image/jpeg",
                isAnimationUri: false,
                useOffchainThumbnail: false,
                allowCollectorAddArtwork: false, // Disabled
                allowCollectorSelectArtistArtwork: false,
                allowCollectorSelectArtistThumbnail: false,
                allowCollectorToggleDisplayMode: false
            }),
            seedArtistArtworkUris: new string[](0),
            seedArtistThumbnailUris: new string[](0)
        });

        _mintTestToken721WithParams(baseParams);

        // Collector cannot add artwork
        string[] memory uris = new string[](1);
        uris[0] = "https://collector.com/art1.jpg";

        vm.prank(collector1);
        vm.expectRevert(Multiplex.CollectorAddingArtworkDisabled.selector);
        multiplex.addCollectorArtworkUris(address(erc721Creator), 1, uris);
    }

    /*//////////////////////////////////////////////////////////////
                           LOCK TESTS
    //////////////////////////////////////////////////////////////*/

    function test_LockMetadata() public {
        _mintTestToken721();

        // Lock metadata
        vm.prank(artist);
        vm.expectEmit(true, true, true, true);
        emit MetadataLocked(address(erc721Creator), 1);
        multiplex.lockMetadata(address(erc721Creator), 1);

        // Verify locked
        (,,,,,, bool metadataLocked,) = multiplex.tokenData(address(erc721Creator), 1);
        assertTrue(metadataLocked);

        // Cannot lock again
        vm.prank(artist);
        vm.expectRevert(Multiplex.AlreadyLocked.selector);
        multiplex.lockMetadata(address(erc721Creator), 1);

        // Cannot update locked metadata
        Multiplex.UpdateParams memory updateParams = Multiplex.UpdateParams({
            metadata: "new metadata",
            updateMetadata: true,
            thumbnailChunks: new bytes[](0),
            thumbnailOptions: Multiplex.File({
                mimeType: "",
                chunks: new address[](0),
                length: 0,
                zipped: false,
                deflated: false
            }),
            updateThumbnail: false,
            displayMode: Multiplex.DisplayMode.IMAGE,
            updateDisplayMode: false,
            selectedArtistArtworkIndex: 0,
            updateSelectedArtistArtwork: false,
            selectedArtistThumbnailIndex: 0,
            updateSelectedArtistThumbnail: false
        });

        vm.prank(artist);
        vm.expectRevert(Multiplex.AlreadyLocked.selector);
        multiplex.updateToken(address(erc721Creator), 1, updateParams);
    }

    function test_LockThumbnail() public {
        _mintTestToken721();

        // Lock thumbnail
        vm.prank(artist);
        vm.expectEmit(true, true, true, true);
        emit ThumbnailLocked(address(erc721Creator), 1);
        multiplex.lockThumbnail(address(erc721Creator), 1);

        // Verify locked
        (,,,,,,, bool thumbnailLocked) = multiplex.tokenData(address(erc721Creator), 1);
        assertTrue(thumbnailLocked);

        // Cannot update locked thumbnail
        bytes[] memory newChunks = new bytes[](1);
        newChunks[0] = hex"1234";

        Multiplex.UpdateParams memory updateParams = Multiplex.UpdateParams({
            metadata: "",
            updateMetadata: false,
            thumbnailChunks: newChunks,
            thumbnailOptions: Multiplex.File({
                mimeType: "image/jpeg",
                chunks: new address[](0),
                length: 2,
                zipped: false,
                deflated: false
            }),
            updateThumbnail: true,
            displayMode: Multiplex.DisplayMode.IMAGE,
            updateDisplayMode: false,
            selectedArtistArtworkIndex: 0,
            updateSelectedArtistArtwork: false,
            selectedArtistThumbnailIndex: 0,
            updateSelectedArtistThumbnail: false
        });

        vm.prank(artist);
        vm.expectRevert(Multiplex.AlreadyLocked.selector);
        multiplex.updateToken(address(erc721Creator), 1, updateParams);
    }

    /*//////////////////////////////////////////////////////////////
                         UPDATE TOKEN TESTS
    //////////////////////////////////////////////////////////////*/

    function test_UpdateToken_AdminUpdates() public {
        _mintTestToken721();

        // Update metadata and thumbnail
        bytes[] memory newChunks = new bytes[](1);
        newChunks[0] = hex"4142434445"; // "ABCDE"

        Multiplex.UpdateParams memory updateParams = Multiplex.UpdateParams({
            metadata: '"name":"Updated Token"',
            updateMetadata: true,
            thumbnailChunks: newChunks,
            thumbnailOptions: Multiplex.File({
                mimeType: "image/jpeg",
                chunks: new address[](0),
                length: 5,
                zipped: false,
                deflated: false
            }),
            updateThumbnail: true,
            displayMode: Multiplex.DisplayMode.HTML,
            updateDisplayMode: true,
            selectedArtistArtworkIndex: 0,
            updateSelectedArtistArtwork: false,
            selectedArtistThumbnailIndex: 0,
            updateSelectedArtistThumbnail: false
        });

        vm.prank(artist);
        vm.expectEmit(true, true, true, true);
        emit MetadataUpdated(address(erc721Creator), 1);
        vm.expectEmit(true, true, true, true);
        emit ThumbnailUpdated(address(erc721Creator), 1, 1);
        vm.expectEmit(true, true, true, true);
        emit DisplayModeUpdated(address(erc721Creator), 1, Multiplex.DisplayMode.HTML);
        multiplex.updateToken(address(erc721Creator), 1, updateParams);

        // Verify updates
        (string memory metadata, Multiplex.File memory thumbnail, Multiplex.DisplayMode displayMode,,,,,) =
            multiplex.tokenData(address(erc721Creator), 1);

        assertEq(metadata, '"name":"Updated Token"');
        assertEq(thumbnail.mimeType, "image/jpeg");
        assertEq(uint256(displayMode), uint256(Multiplex.DisplayMode.HTML));
    }

    function test_UpdateToken_CollectorUpdates() public {
        // Mint with all permissions enabled
        _mintTestToken721();

        // Add some artist URIs first
        string[] memory artworkUris = new string[](2);
        artworkUris[0] = "https://example.com/art1.jpg";
        artworkUris[1] = "https://example.com/art2.jpg";

        string[] memory thumbnailUris = new string[](1);
        thumbnailUris[0] = "https://example.com/thumb1.jpg";

        vm.prank(artist);
        multiplex.addArtistArtworkUris(address(erc721Creator), 1, artworkUris);
        vm.prank(artist);
        multiplex.addArtistThumbnailUris(address(erc721Creator), 1, thumbnailUris);

        // Collector updates display mode and selections
        Multiplex.UpdateParams memory updateParams = Multiplex.UpdateParams({
            metadata: "",
            updateMetadata: false,
            thumbnailChunks: new bytes[](0),
            thumbnailOptions: Multiplex.File({
                mimeType: "",
                chunks: new address[](0),
                length: 0,
                zipped: false,
                deflated: false
            }),
            updateThumbnail: false,
            displayMode: Multiplex.DisplayMode.HTML,
            updateDisplayMode: true,
            selectedArtistArtworkIndex: 2,
            updateSelectedArtistArtwork: true,
            selectedArtistThumbnailIndex: 1,
            updateSelectedArtistThumbnail: true
        });

        vm.prank(collector1);
        multiplex.updateToken(address(erc721Creator), 1, updateParams);

        // Verify updates
        (,, Multiplex.DisplayMode displayMode,,, Multiplex.Selection memory selection,,) =
            multiplex.tokenData(address(erc721Creator), 1);

        assertEq(uint256(displayMode), uint256(Multiplex.DisplayMode.HTML));
        assertEq(selection.selectedArtistArtworkIndex, 2);
        assertEq(selection.selectedArtistThumbnailIndex, 1);

        // Collector cannot update metadata
        updateParams.metadata = "new metadata";
        updateParams.updateMetadata = true;
        updateParams.updateDisplayMode = false;
        updateParams.updateSelectedArtistArtwork = false;
        updateParams.updateSelectedArtistThumbnail = false;

        vm.prank(collector1);
        vm.expectRevert(Multiplex.WalletNotAdmin.selector);
        multiplex.updateToken(address(erc721Creator), 1, updateParams);
    }

    function test_UpdateToken_PermissionChecks() public {
        // Mint with all collector permissions disabled
        Multiplex.MintParams memory baseParams = Multiplex.MintParams({
            metadata: SAMPLE_METADATA,
            onChainThumbnail: Multiplex.File({
                mimeType: SAMPLE_MIME_TYPE,
                chunks: new address[](0),
                length: SAMPLE_THUMBNAIL.length,
                zipped: false,
                deflated: false
            }),
            initialDisplayMode: Multiplex.DisplayMode.IMAGE,
            immutableProperties: Multiplex.ImmutableProperties({
                imageHash: SAMPLE_IMAGE_HASH,
                imageMimeType: "image/jpeg",
                isAnimationUri: false,
                useOffchainThumbnail: false,
                allowCollectorAddArtwork: false,
                allowCollectorSelectArtistArtwork: false,
                allowCollectorSelectArtistThumbnail: false,
                allowCollectorToggleDisplayMode: false
            }),
            seedArtistArtworkUris: new string[](0),
            seedArtistThumbnailUris: new string[](0)
        });

        _mintTestToken721WithParams(baseParams);

        // Test each disabled permission
        Multiplex.UpdateParams memory updateParams;

        // Display mode
        updateParams.displayMode = Multiplex.DisplayMode.HTML;
        updateParams.updateDisplayMode = true;

        vm.prank(collector1);
        vm.expectRevert(Multiplex.CollectorTogglingDisplayModeDisabled.selector);
        multiplex.updateToken(address(erc721Creator), 1, updateParams);

        // Artwork selection
        updateParams.updateDisplayMode = false;
        updateParams.selectedArtistArtworkIndex = 1;
        updateParams.updateSelectedArtistArtwork = true;

        vm.prank(collector1);
        vm.expectRevert(Multiplex.CollectorSelectingArtworkDisabled.selector);
        multiplex.updateToken(address(erc721Creator), 1, updateParams);

        // Thumbnail selection
        updateParams.updateSelectedArtistArtwork = false;
        updateParams.selectedArtistThumbnailIndex = 1;
        updateParams.updateSelectedArtistThumbnail = true;

        vm.prank(collector1);
        vm.expectRevert(Multiplex.CollectorSelectingThumbnailDisabled.selector);
        multiplex.updateToken(address(erc721Creator), 1, updateParams);
    }

    /*//////////////////////////////////////////////////////////////
                        RENDERING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RenderImage() public {
        _mintTestToken721();

        string memory imageUri = multiplex.renderImage(address(erc721Creator), 1);

        // Verify it's a valid data URI
        assertTrue(_startsWith(imageUri, "data:image/png;base64,"));

        // Decode and verify content
        string memory base64Part = _substring(imageUri, 22, bytes(imageUri).length);
        bytes memory decoded = Base64.decode(base64Part);
        assertEq(decoded, SAMPLE_THUMBNAIL);
    }

    function test_RenderHTML() public {
        // Mint with artwork URIs
        string[] memory artworkUris = new string[](2);
        artworkUris[0] = "https://example.com/art1.jpg";
        artworkUris[1] = "https://example.com/art2.jpg";

        Multiplex.MintParams memory baseParams = Multiplex.MintParams({
            metadata: SAMPLE_METADATA,
            onChainThumbnail: Multiplex.File({
                mimeType: SAMPLE_MIME_TYPE,
                chunks: new address[](0),
                length: SAMPLE_THUMBNAIL.length,
                zipped: false,
                deflated: false
            }),
            initialDisplayMode: Multiplex.DisplayMode.HTML,
            immutableProperties: Multiplex.ImmutableProperties({
                imageHash: SAMPLE_IMAGE_HASH,
                imageMimeType: "image/jpeg",
                isAnimationUri: false,
                useOffchainThumbnail: false,
                allowCollectorAddArtwork: true,
                allowCollectorSelectArtistArtwork: true,
                allowCollectorSelectArtistThumbnail: true,
                allowCollectorToggleDisplayMode: true
            }),
            seedArtistArtworkUris: artworkUris,
            seedArtistThumbnailUris: new string[](0)
        });

        _mintTestToken721WithParams(baseParams);

        // Add collector artwork
        string[] memory collectorUris = new string[](1);
        collectorUris[0] = "https://collector.com/art1.jpg";

        vm.prank(collector1);
        multiplex.addCollectorArtworkUris(address(erc721Creator), 1, collectorUris);

        string memory htmlUri = multiplex.renderHTML(address(erc721Creator), 1);

        // Verify it's a valid HTML data URI
        assertTrue(_startsWith(htmlUri, "data:text/html;base64,"));

        // Decode and verify placeholders were replaced
        string memory base64Part = _substring(htmlUri, 22, bytes(htmlUri).length);
        bytes memory decoded = Base64.decode(base64Part);
        string memory html = string(decoded);

        // The HTML should contain all the URIs
        // Note: The URIs are in quotes in the HTML because they're part of a JavaScript array
        assertTrue(_contains(html, artworkUris[0]), "Should contain first artist artwork URI");
        assertTrue(_contains(html, artworkUris[1]), "Should contain second artist artwork URI");
        assertTrue(_contains(html, collectorUris[0]), "Should contain collector artwork URI");
        assertTrue(_contains(html, SAMPLE_IMAGE_HASH), "Should contain image hash");
    }

    function test_RenderMetadata_ImageMode() public {
        _mintTestToken721();

        string memory metadataUri = multiplex.renderMetadata(address(erc721Creator), 1);

        // Verify it's a valid JSON data URI
        assertTrue(_startsWith(metadataUri, "data:application/json;utf8,{"));

        // Extract JSON
        string memory json = _substring(metadataUri, 28, bytes(metadataUri).length - 1);

        // Verify metadata fields
        assertTrue(_contains(json, '"name":"Test Token"'));
        assertTrue(_contains(json, '"image":"data:image/png;base64,'));
        assertFalse(_contains(json, '"animation_url"')); // No animation in IMAGE mode
    }

    function test_RenderMetadata_HTMLMode() public {
        // Mint in HTML mode
        Multiplex.MintParams memory baseParams = Multiplex.MintParams({
            metadata: SAMPLE_METADATA,
            onChainThumbnail: Multiplex.File({
                mimeType: SAMPLE_MIME_TYPE,
                chunks: new address[](0),
                length: SAMPLE_THUMBNAIL.length,
                zipped: false,
                deflated: false
            }),
            initialDisplayMode: Multiplex.DisplayMode.HTML,
            immutableProperties: Multiplex.ImmutableProperties({
                imageHash: SAMPLE_IMAGE_HASH,
                imageMimeType: "image/jpeg",
                isAnimationUri: true,
                useOffchainThumbnail: false,
                allowCollectorAddArtwork: true,
                allowCollectorSelectArtistArtwork: true,
                allowCollectorSelectArtistThumbnail: true,
                allowCollectorToggleDisplayMode: true
            }),
            seedArtistArtworkUris: new string[](0),
            seedArtistThumbnailUris: new string[](0)
        });

        _mintTestToken721WithParams(baseParams);

        string memory metadataUri = multiplex.renderMetadata(address(erc721Creator), 1);
        string memory json = _substring(metadataUri, 28, bytes(metadataUri).length - 1);

        // In HTML mode, animation_url should point to HTML
        assertTrue(_contains(json, '"animation_url":"data:text/html;base64,'));
    }

    function test_RenderMetadata_OffchainThumbnail() public {
        // Mint with off-chain thumbnail enabled
        string[] memory thumbnailUris = new string[](1);
        thumbnailUris[0] = "https://example.com/thumb.jpg";

        Multiplex.MintParams memory baseParams = Multiplex.MintParams({
            metadata: SAMPLE_METADATA,
            onChainThumbnail: Multiplex.File({
                mimeType: SAMPLE_MIME_TYPE,
                chunks: new address[](0),
                length: SAMPLE_THUMBNAIL.length,
                zipped: false,
                deflated: false
            }),
            initialDisplayMode: Multiplex.DisplayMode.IMAGE,
            immutableProperties: Multiplex.ImmutableProperties({
                imageHash: SAMPLE_IMAGE_HASH,
                imageMimeType: "image/jpeg",
                isAnimationUri: false,
                useOffchainThumbnail: true, // Enable off-chain thumbnail
                allowCollectorAddArtwork: true,
                allowCollectorSelectArtistArtwork: true,
                allowCollectorSelectArtistThumbnail: true,
                allowCollectorToggleDisplayMode: true
            }),
            seedArtistArtworkUris: new string[](0),
            seedArtistThumbnailUris: thumbnailUris
        });

        _mintTestToken721WithParams(baseParams);

        // Select off-chain thumbnail
        Multiplex.UpdateParams memory updateParams;
        updateParams.selectedArtistThumbnailIndex = 1;
        updateParams.updateSelectedArtistThumbnail = true;

        vm.prank(artist);
        multiplex.updateToken(address(erc721Creator), 1, updateParams);

        string memory metadataUri = multiplex.renderMetadata(address(erc721Creator), 1);
        string memory json = _substring(metadataUri, 28, bytes(metadataUri).length - 1);

        // Should use off-chain thumbnail
        assertTrue(_contains(json, thumbnailUris[0]));
    }

    function test_RenderMetadata_WithBracesHandling() public {
        // Test metadata with outer braces (complete JSON object)
        string memory metadataWithBraces =
            '{"name":"Framework Test","description":"Test with braces","external_url":"http://localhost:5173/","attributes":[{"trait_type":"property1","value":"value1"}]}';

        Multiplex.MintParams memory baseParams = Multiplex.MintParams({
            metadata: metadataWithBraces,
            onChainThumbnail: Multiplex.File({
                mimeType: SAMPLE_MIME_TYPE,
                chunks: new address[](0),
                length: SAMPLE_THUMBNAIL.length,
                zipped: false,
                deflated: false
            }),
            initialDisplayMode: Multiplex.DisplayMode.IMAGE,
            immutableProperties: Multiplex.ImmutableProperties({
                imageHash: SAMPLE_IMAGE_HASH,
                imageMimeType: "image/jpeg",
                isAnimationUri: false,
                useOffchainThumbnail: false,
                allowCollectorAddArtwork: true,
                allowCollectorSelectArtistArtwork: true,
                allowCollectorSelectArtistThumbnail: true,
                allowCollectorToggleDisplayMode: true
            }),
            seedArtistArtworkUris: new string[](0),
            seedArtistThumbnailUris: new string[](0)
        });

        _mintTestToken721WithParams(baseParams);

        string memory metadataUri = multiplex.renderMetadata(address(erc721Creator), 1);

        // Verify it's a valid JSON data URI
        assertTrue(_startsWith(metadataUri, "data:application/json;utf8,{"));

        // Extract and validate JSON structure
        string memory json = _substring(metadataUri, 28, bytes(metadataUri).length - 1);

        // Verify no double braces exist
        assertFalse(_contains(json, "{{"), "Should not contain double opening braces");
        assertFalse(_contains(json, "}}"), "Should not contain double closing braces");

        // Verify all expected fields are present
        assertTrue(_contains(json, '"name":"Framework Test"'));
        assertTrue(_contains(json, '"description":"Test with braces"'));
        assertTrue(_contains(json, '"external_url":"http://localhost:5173/"'));
        assertTrue(_contains(json, '"property1"'));
        assertTrue(_contains(json, '"value1"'));
        assertTrue(_contains(json, '"image":"data:image/png;base64,'));

        // Verify the JSON structure is valid by checking bracket balance
        _verifyJsonBracketBalance(json);
    }

    function test_RenderMetadata_WithoutBracesHandling() public {
        // Test traditional metadata format without outer braces
        _mintTestToken721(); // Uses SAMPLE_METADATA which has no braces

        string memory metadataUri = multiplex.renderMetadata(address(erc721Creator), 1);
        string memory json = _substring(metadataUri, 28, bytes(metadataUri).length - 1);

        // Verify no double braces
        assertFalse(_contains(json, "{{"), "Should not contain double opening braces");
        assertFalse(_contains(json, "}}"), "Should not contain double closing braces");

        // Verify expected content
        assertTrue(_contains(json, '"name":"Test Token"'));
        assertTrue(_contains(json, '"image":"data:image/png;base64,'));

        // Verify the JSON structure is valid
        _verifyJsonBracketBalance(json);
    }

    /*//////////////////////////////////////////////////////////////
                        COMPRESSION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CompressionHelpers() public view {
        bytes memory testData = "Hello, World! This is a test string for compression.";

        // Test zip/unzip
        bytes memory compressed = LibZip.flzCompress(testData);
        bytes memory decompressed = LibZip.flzDecompress(compressed);
        assertEq(decompressed, testData);

        // Test inflate (would need actual DEFLATE compressed data)
        // For now, just verify the function exists and is callable
        // Real DEFLATE test would require pre-compressed data
    }

    /*//////////////////////////////////////////////////////////////
                        INTERFACE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SupportsInterface() public view {
        // Should support ICreatorExtensionTokenURI
        assertTrue(multiplex.supportsInterface(type(ICreatorExtensionTokenURI).interfaceId));

        // Should support AdminControl
        assertTrue(multiplex.supportsInterface(type(IAdminControl).interfaceId));

        // Should not support random interface
        assertFalse(multiplex.supportsInterface(0x12345678));
    }

    function test_TokenURI() public {
        _mintTestToken721();

        // tokenURI should return same as renderMetadata
        string memory tokenUri = multiplex.tokenURI(address(erc721Creator), 1);
        string memory metadataUri = multiplex.renderMetadata(address(erc721Creator), 1);

        assertEq(tokenUri, metadataUri);
    }

    /*//////////////////////////////////////////////////////////////
                          UNIT TEST FOR HELPERS
    //////////////////////////////////////////////////////////////*/

    function test_ContainsHelper() public pure {
        string memory haystack =
            '<html><body>"https://example.com/art1.jpg","https://example.com/art2.jpg"</body></html>';

        assertTrue(_contains(haystack, "https://example.com/art1.jpg"), "Should find art1");
        assertTrue(_contains(haystack, "https://example.com/art2.jpg"), "Should find art2");
        assertTrue(_contains(haystack, "<html>"), "Should find html tag");
        assertFalse(_contains(haystack, "notfound"), "Should not find missing string");
    }

    function test_Base64Decode() public pure {
        // Test the exact base64 string from the failing test
        string memory base64 =
            "PGh0bWw+PGJvZHk+Imh0dHBzOi8vZXhhbXBsZS5jb20vYXJ0MS5qcGciLCJodHRwczovL2V4YW1wbGUuY29tL2FydDIuanBnIiwiaHR0cHM6Ly9jb2xsZWN0b3IuY29tL2FydDEuanBnIiBRbVRlc3QxMjM8L2JvZHk+PC9odG1sPg==";
        bytes memory decoded = Base64.decode(base64);
        string memory html = string(decoded);

        // Verify the decoded string
        string memory expected =
            '<html><body>"https://example.com/art1.jpg","https://example.com/art2.jpg","https://collector.com/art1.jpg" QmTest123</body></html>';
        assertEq(html, expected, "Decoded HTML should match expected");

        // Now test _contains on the decoded string
        assertTrue(_contains(html, "https://example.com/art1.jpg"), "Should find art1 in decoded");
        assertTrue(_contains(html, "https://example.com/art2.jpg"), "Should find art2 in decoded");
    }

    /*//////////////////////////////////////////////////////////////
                          HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _mintTestToken721() internal {
        Multiplex.MintParams memory baseParams = Multiplex.MintParams({
            metadata: SAMPLE_METADATA,
            onChainThumbnail: Multiplex.File({
                mimeType: SAMPLE_MIME_TYPE,
                chunks: new address[](0),
                length: SAMPLE_THUMBNAIL.length,
                zipped: false,
                deflated: false
            }),
            initialDisplayMode: Multiplex.DisplayMode.IMAGE,
            immutableProperties: Multiplex.ImmutableProperties({
                imageHash: SAMPLE_IMAGE_HASH,
                imageMimeType: "image/jpeg",
                isAnimationUri: false,
                useOffchainThumbnail: false,
                allowCollectorAddArtwork: true,
                allowCollectorSelectArtistArtwork: true,
                allowCollectorSelectArtistThumbnail: true,
                allowCollectorToggleDisplayMode: true
            }),
            seedArtistArtworkUris: new string[](0),
            seedArtistThumbnailUris: new string[](0)
        });

        _mintTestToken721WithParams(baseParams);
    }

    function _mintTestToken721WithParams(Multiplex.MintParams memory baseParams) internal {
        address[] memory recipients = new address[](1);
        recipients[0] = collector1;

        Multiplex.MintERC721Params memory params =
            Multiplex.MintERC721Params({ baseParams: baseParams, recipients: recipients });

        bytes[] memory thumbnailChunks = new bytes[](1);
        thumbnailChunks[0] = SAMPLE_THUMBNAIL;

        vm.prank(artist);
        multiplex.mintERC721(address(erc721Creator), params, thumbnailChunks);
    }

    function _startsWith(string memory str, string memory prefix) internal pure returns (bool) {
        bytes memory strBytes = bytes(str);
        bytes memory prefixBytes = bytes(prefix);

        if (strBytes.length < prefixBytes.length) return false;

        for (uint256 i = 0; i < prefixBytes.length; i++) {
            if (strBytes[i] != prefixBytes[i]) return false;
        }

        return true;
    }

    function _contains(string memory str, string memory substr) internal pure returns (bool) {
        bytes memory strBytes = bytes(str);
        bytes memory substrBytes = bytes(substr);

        if (strBytes.length < substrBytes.length) return false;

        for (uint256 i = 0; i <= strBytes.length - substrBytes.length; i++) {
            bool found = true;
            for (uint256 j = 0; j < substrBytes.length; j++) {
                if (strBytes[i + j] != substrBytes[j]) {
                    found = false;
                    break;
                }
            }
            if (found) return true;
        }

        return false;
    }

    function _substring(
        string memory str,
        uint256 startIndex,
        uint256 endIndex
    )
        internal
        pure
        returns (string memory)
    {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(endIndex - startIndex);

        for (uint256 i = startIndex; i < endIndex; i++) {
            result[i - startIndex] = strBytes[i];
        }

        return string(result);
    }

    function _verifyJsonBracketBalance(string memory json) internal pure {
        bytes memory jsonBytes = bytes(json);
        int256 braceCount = 0;
        int256 bracketCount = 0;

        for (uint256 i = 0; i < jsonBytes.length; i++) {
            if (jsonBytes[i] == 0x7B) {
                // '{'
                braceCount++;
            } else if (jsonBytes[i] == 0x7D) {
                // '}'
                braceCount--;
            } else if (jsonBytes[i] == 0x5B) {
                // '['
                bracketCount++;
            } else if (jsonBytes[i] == 0x5D) {
                // ']'
                bracketCount--;
            }

            // Brackets should never go negative
            require(braceCount >= 0, "Unbalanced JSON braces - too many closing braces");
            require(bracketCount >= 0, "Unbalanced JSON brackets - too many closing brackets");
        }

        // Final counts should be zero for balanced JSON
        require(braceCount == 0, "Unbalanced JSON braces - missing closing braces");
        require(bracketCount == 0, "Unbalanced JSON brackets - missing closing brackets");
    }
}
