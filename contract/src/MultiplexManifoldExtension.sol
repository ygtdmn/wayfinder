// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

import { AdminControl } from "@manifoldxyz/libraries-solidity/contracts/access/AdminControl.sol";
import { Multiplex } from "./Multiplex.sol";
import { Lifebuoy } from "solady/utils/Lifebuoy.sol";
import { IERC721CreatorCore } from "@manifoldxyz/creator-core-solidity/contracts/core/IERC721CreatorCore.sol";
import { IERC1155CreatorCore } from "@manifoldxyz/creator-core-solidity/contracts/core/IERC1155CreatorCore.sol";
import { ICreatorExtensionTokenURI } from
    "@manifoldxyz/creator-core-solidity/contracts/extensions/ICreatorExtensionTokenURI.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { OwnershipSelectors } from "./libraries/OwnershipSelectors.sol";

/**
 * @title MultiplexManifoldExtension
 * @author Yigit Duman (@yigitduman)
 * @notice A Manifold Creator Extension for minting tokens with Multiplex
 */
contract MultiplexManifoldExtension is AdminControl, ICreatorExtensionTokenURI, Lifebuoy {
    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The Multiplex contract that handles token data and rendering
    Multiplex public multiplex;

    /*//////////////////////////////////////////////////////////////
                            CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/

    error WalletNotAdmin();
    error ContractMustImplementERC721OrERC1155();
    error InvalidIndexRange();
    error MultiplexNotSet();
    error InvalidRecipient();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event TokenMintedERC721(address indexed creator, uint256 indexed tokenId, address indexed recipient);
    event TokenMintedERC1155(
        address indexed creator, uint256 indexed tokenId, address[] indexed recipients, uint256[] quantities
    );
    event MultiplexUpdated(address indexed newMultiplex);

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Initialize the contract with a Multiplex instance
    /// @param _multiplex The Multiplex contract address
    constructor(address _multiplex) {
        multiplex = Multiplex(_multiplex);
    }

    /*//////////////////////////////////////////////////////////////
                            ACCESS HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Check if the caller is an admin of the contract
    /// @param contractAddress The contract to check admin status for
    /// @return True if caller is admin, false otherwise
    function _isContractAdmin(address contractAddress) internal view returns (bool) {
        // Try to check if it's a Manifold contract with AdminControl
        try AdminControl(contractAddress).isAdmin(msg.sender) returns (bool isAdmin) {
            return isAdmin;
        } catch {
            // If not, return false
            return false;
        }
    }

    /// @notice Restricts function access to contract admins only
    /// @param contractAddress The contract to check admin status for
    modifier contractAdminRequired(address contractAddress) {
        require(_isContractAdmin(contractAddress), WalletNotAdmin());
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Update the Multiplex contract address (admin only)
    /// @param _multiplex The new Multiplex contract address
    function setMultiplex(address _multiplex) external adminRequired {
        multiplex = Multiplex(_multiplex);
        emit MultiplexUpdated(_multiplex);
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
    function mintERC1155(
        address contractAddress,
        address[] calldata recipients,
        uint256[] calldata quantities,
        Multiplex.InitConfig memory config,
        bytes[] calldata thumbnailChunks
    )
        external
        payable
        contractAdminRequired(contractAddress)
    {
        require(address(multiplex) != address(0), MultiplexNotSet());
        require(recipients.length > 0, InvalidIndexRange());
        require(quantities.length > 0, InvalidIndexRange());

        // Validate quantities array: must be single element (same for all) or same length as recipients (different
        // amounts)
        require(quantities.length == 1 || quantities.length == recipients.length, InvalidIndexRange());

        // Mint one token to multiple recipients via Manifold ERC1155 creator contract
        string[] memory uris = new string[](0); // Empty array uses default URI
        uint256[] memory tokenIds = IERC1155CreatorCore(contractAddress).mintExtensionNew(recipients, quantities, uris);

        // Set ownership config with ERC1155 standard
        config.ownership = Multiplex.OwnershipConfig({
            selector: OwnershipSelectors.BALANCE_OF_ERC1155,
            style: Multiplex.OwnershipStyle.BALANCE_OF_ERC1155
        });

        // Initialize token data in Multiplex and emit events
        uint256 tokenId = tokenIds[0]; // There's only one token minted
        multiplex.initializeTokenData(contractAddress, tokenId, config, thumbnailChunks);

        emit TokenMintedERC1155(contractAddress, tokenId, recipients, quantities);
    }

    /// @notice Mint ERC721 tokens to multiple addresses (one per address)
    /// @param contractAddress The ERC721 contract address
    /// @param recipient Address to mint to
    /// @param config Mint configuration
    /// @param thumbnailChunks On-chain thumbnail data chunks (only if thumbnailKind == ON_CHAIN)
    function mintERC721(
        address contractAddress,
        address recipient,
        Multiplex.InitConfig memory config,
        bytes[] calldata thumbnailChunks
    )
        external
        payable
        contractAdminRequired(contractAddress)
    {
        require(address(multiplex) != address(0), MultiplexNotSet());
        require(recipient != address(0), InvalidRecipient());

        // Mint tokens via Manifold creator contract
        uint256 tokenId = IERC721CreatorCore(contractAddress).mintExtension(recipient);

        // Set ownership config with ERC721 standard
        config.ownership = Multiplex.OwnershipConfig({
            selector: OwnershipSelectors.OWNER_OF,
            style: Multiplex.OwnershipStyle.OWNER_OF
        });

        // Initialize token data in Multiplex and emit events
        multiplex.initializeTokenData(contractAddress, tokenId, config, thumbnailChunks);
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
        return multiplex.renderMetadata(creator, tokenId);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERFACE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get Multiplex contract address
    /// @return The Multiplex contract address
    function getMultiplex() external view returns (address) {
        return address(multiplex);
    }

    /// @notice Check if contract supports a given interface
    /// @param interfaceId The interface ID to check
    /// @return True if interface is supported
    function supportsInterface(bytes4 interfaceId) public view virtual override(AdminControl, IERC165) returns (bool) {
        return interfaceId == type(ICreatorExtensionTokenURI).interfaceId || AdminControl.supportsInterface(interfaceId)
            || super.supportsInterface(interfaceId);
    }
}
