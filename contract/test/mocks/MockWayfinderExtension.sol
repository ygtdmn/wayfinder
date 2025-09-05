// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

import { IWayfinder } from "src/interfaces/IWayfinder.sol";
import { IWayfinderCreator } from "src/interfaces/IWayfinderCreator.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

contract MockWayfinderExtension is IWayfinderCreator {
    IWayfinder public wayfinder;
    mapping(address => bool) private _admins;
    mapping(address => mapping(address => mapping(uint256 => bool))) private _tokenOwners;

    constructor(address _wayfinder) {
        wayfinder = IWayfinder(_wayfinder);
        _admins[msg.sender] = true;
    }

    function setAdmin(address account, bool adminStatus) external {
        require(_admins[msg.sender], "Not admin");
        _admins[account] = adminStatus;
    }

    function isAdmin(address account) external view returns (bool) {
        return _admins[account];
    }

    function setTokenOwner(address contractAddress, address account, uint256 tokenId, bool isOwner) external {
        _tokenOwners[contractAddress][account][tokenId] = isOwner;
    }

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
        // Use the stored mock data if available, otherwise delegate to the real contract
        if (_tokenOwners[creatorContract][account][tokenId]) {
            return true;
        }

        // Try to call the real contract's isTokenOwner if it implements IWayfinderCreator
        try IWayfinderCreator(creatorContract).isTokenOwner(creatorContract, account, tokenId) returns (bool result) {
            return result;
        } catch {
            return false;
        }
    }

    function initializeTokenData(
        address contractAddress,
        uint256 tokenId,
        IWayfinder.InitConfig calldata config,
        bytes[] calldata thumbnailChunks,
        string[] calldata htmlTemplateChunks
    )
        external
    {
        require(_admins[msg.sender], "Not admin");
        wayfinder.initializeTokenData(contractAddress, tokenId, config, thumbnailChunks, htmlTemplateChunks);
    }

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IWayfinderCreator).interfaceId || interfaceId == type(IERC165).interfaceId;
    }
}
