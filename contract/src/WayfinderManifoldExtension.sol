// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

import { AdminControl } from "@manifoldxyz/libraries-solidity/contracts/access/AdminControl.sol";
import { IWayfinder } from "./interfaces/IWayfinder.sol";
import { IWayfinderCreator } from "./interfaces/IWayfinderCreator.sol";
import { Lifebuoy } from "solady/utils/Lifebuoy.sol";
import { IERC721CreatorCore } from "@manifoldxyz/creator-core-solidity/contracts/core/IERC721CreatorCore.sol";
import { IERC1155CreatorCore } from "@manifoldxyz/creator-core-solidity/contracts/core/IERC1155CreatorCore.sol";
import { ICreatorExtensionTokenURI } from
    "@manifoldxyz/creator-core-solidity/contracts/extensions/ICreatorExtensionTokenURI.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

/**
 * @title WayfinderManifoldExtension
 * @author Yigit Duman (@yigitduman)
 * @notice A Manifold Creator Extension for minting tokens with Wayfinder
 */
contract WayfinderManifoldExtension is AdminControl, ICreatorExtensionTokenURI, IWayfinderCreator, Lifebuoy {
    /// @notice The Wayfinder contract that handles token data and rendering
    IWayfinder public wayfinder;

    /*//////////////////////////////////////////////////////////////
                            CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/

    error WalletNotAdmin();
    error InvalidIndexRange();
    error WayfinderNotSet();
    error InvalidRecipient();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event TokenMintedERC721(address indexed creator, uint256 indexed tokenId, address indexed recipient);
    event TokenMintedERC1155(
        address indexed creator, uint256 indexed tokenId, address[] indexed recipients, uint256[] quantities
    );
    event WayfinderUpdated(address indexed newWayfinder);

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Initialize the contract with a Wayfinder instance
    /// @param _wayfinder The Wayfinder contract address
    constructor(address _wayfinder) {
        wayfinder = IWayfinder(_wayfinder);
    }

    /*//////////////////////////////////////////////////////////////
                             WAYFINDER
    //////////////////////////////////////////////////////////////*/

    /// @notice Update the Wayfinder contract address (admin only)
    /// @param _wayfinder The new Wayfinder contract address
    function setWayfinder(address _wayfinder) external adminRequired {
        wayfinder = IWayfinder(_wayfinder);
        emit WayfinderUpdated(_wayfinder);
    }

    /// @notice Get Wayfinder contract address
    /// @return The Wayfinder contract address
    function getWayfinder() external view returns (address) {
        return address(wayfinder);
    }

    /*//////////////////////////////////////////////////////////////
                            ACCESS HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Check if the caller is an admin of the contract
    /// @param contractAddress The contract to check admin status for
    /// @return True if caller is admin, false otherwise
    function _isContractAdmin(address contractAddress) internal view returns (bool) {
        (bool ok, bytes memory ret) =
            contractAddress.staticcall(abi.encodeWithSelector(AdminControl.isAdmin.selector, msg.sender));
        if (ok && ret.length >= 32) {
            return abi.decode(ret, (bool));
        }
        return false;
    }

    /// @notice Restricts function access to contract admins only
    /// @param contractAddress The contract to check admin status for
    modifier contractAdminRequired(address contractAddress) {
        require(_isContractAdmin(contractAddress), WalletNotAdmin());
        _;
    }

    /// @notice Check if an account owns a specific token from a creator contract
    /// @param creatorContract The creator contract address to check ownership for
    /// @param account The account to check ownership for
    /// @param tokenId The token ID to check ownership for
    /// @return True if account owns the token, false otherwise
    function isTokenOwner(
        address creatorContract,
        address account,
        uint256 tokenId
    )
        external
        view
        override
        returns (bool)
    {
        // Try ERC721 ownerOf first
        (bool ok, bytes memory ret) =
            creatorContract.staticcall(abi.encodeWithSelector(IERC721.ownerOf.selector, tokenId));
        if (ok && ret.length >= 32) {
            return abi.decode(ret, (address)) == account;
        }

        // Try ERC1155 balanceOf if ERC721 fails
        (ok, ret) = creatorContract.staticcall(abi.encodeWithSelector(IERC1155.balanceOf.selector, account, tokenId));
        if (ok && ret.length >= 32) {
            return abi.decode(ret, (uint256)) > 0;
        }

        return false;
    }

    /*//////////////////////////////////////////////////////////////
                                MINTING
    //////////////////////////////////////////////////////////////*/

    /// @notice Mint one ERC1155 token and send it to multiple addresses with specified quantities
    /// @param contractAddress The ERC1155 contract address
    /// @param recipients Addresses to mint to (all get the same token)
    /// @param quantities Quantities for each recipient (can be single element for same amount to all, or multi-element
    /// for different amounts)
    /// @param config Mint configuration
    /// @param thumbnailChunks On-chain thumbnail data chunks (only if thumbnailKind == ON_CHAIN)
    /// @param htmlTemplateChunks HTML template chunks (if config.htmlTemplate has empty chunks, use these)
    function mintERC1155(
        address contractAddress,
        address[] calldata recipients,
        uint256[] calldata quantities,
        IWayfinder.InitConfig memory config,
        bytes[] calldata thumbnailChunks,
        string[] calldata htmlTemplateChunks
    )
        external
        payable
        contractAdminRequired(contractAddress)
    {
        require(address(wayfinder) != address(0), WayfinderNotSet());
        require(recipients.length > 0, InvalidIndexRange());
        require(quantities.length > 0, InvalidIndexRange());

        // Validate quantities array: must be single element (same for all) or same length as recipients (different
        // amounts)
        require(quantities.length == 1 || quantities.length == recipients.length, InvalidIndexRange());

        // Mint one token to multiple recipients via Manifold ERC1155 creator contract
        string[] memory uris = new string[](0); // Empty array uses default URI
        uint256[] memory tokenIds = IERC1155CreatorCore(contractAddress).mintExtensionNew(recipients, quantities, uris);

        // Initialize token data in Wayfinder and emit events
        uint256 tokenId = tokenIds[0]; // There's only one token minted
        wayfinder.initializeTokenData(contractAddress, tokenId, config, thumbnailChunks, htmlTemplateChunks);

        emit TokenMintedERC1155(contractAddress, tokenId, recipients, quantities);
    }

    /// @notice Mint an ERC721 token to a single address
    /// @param contractAddress The ERC721 contract address
    /// @param recipient Address to mint to
    /// @param config Mint configuration
    /// @param thumbnailChunks On-chain thumbnail data chunks (only if thumbnailKind == ON_CHAIN)
    /// @param htmlTemplateChunks HTML template chunks (if config.htmlTemplate has empty chunks, use these)
    function mintERC721(
        address contractAddress,
        address recipient,
        IWayfinder.InitConfig memory config,
        bytes[] calldata thumbnailChunks,
        string[] calldata htmlTemplateChunks
    )
        external
        payable
        contractAdminRequired(contractAddress)
    {
        require(address(wayfinder) != address(0), WayfinderNotSet());
        require(recipient != address(0), InvalidRecipient());

        // Mint tokens via Manifold creator contract
        uint256 tokenId = IERC721CreatorCore(contractAddress).mintExtension(recipient);

        // Initialize token data in Wayfinder and emit events
        wayfinder.initializeTokenData(contractAddress, tokenId, config, thumbnailChunks, htmlTemplateChunks);
        emit TokenMintedERC721(contractAddress, tokenId, recipient);
    }

    /*//////////////////////////////////////////////////////////////
                               TOKEN URI
    //////////////////////////////////////////////////////////////*/

    /// @notice Get the token URI for a given token
    /// @param creator The creator contract address
    /// @param tokenId The token ID
    /// @return The token URI
    function tokenURI(address creator, uint256 tokenId) external view override returns (string memory) {
        return wayfinder.renderMetadata(creator, tokenId);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERFACE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Check if contract supports a given interface
    /// @param interfaceId The interface ID to check
    /// @return True if interface is supported
    function supportsInterface(bytes4 interfaceId) public view virtual override(AdminControl, IERC165) returns (bool) {
        return interfaceId == type(ICreatorExtensionTokenURI).interfaceId
            || interfaceId == type(IWayfinderCreator).interfaceId || AdminControl.supportsInterface(interfaceId)
            || super.supportsInterface(interfaceId);
    }
}
