// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

import { IMultiplexCreator } from "src/interfaces/IMultiplexCreator.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title MockCustomOwnership
 * @dev Mock contract for testing custom ownership styles in Multiplex
 */
contract MockCustomOwnership is IMultiplexCreator {
    address private _tokenOwner;
    mapping(address => bool) private _admins;
    address private _contractOwner;

    constructor(address _owner) {
        _tokenOwner = _owner;
        _contractOwner = msg.sender;
        _admins[msg.sender] = true;
    }

    function isOwner(address who) external view returns (bool) {
        return who == _tokenOwner;
    }

    function setTokenOwner(address _newOwner) external {
        _tokenOwner = _newOwner;
    }

    function isAdmin(address account) external view returns (bool) {
        return _admins[account];
    }

    function owner() external view returns (address) {
        return _contractOwner;
    }

    function setAdmin(address account, bool adminStatus) external {
        require(_admins[msg.sender], "Not admin");
        _admins[account] = adminStatus;
    }

    function isTokenOwner(
        address creatorContract,
        address account,
        uint256 /* tokenId */
    ) external view override returns (bool) {
        if (creatorContract == address(this)) {
            return this.isOwner(account);
        }
        return false;
    }

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IMultiplexCreator).interfaceId || interfaceId == type(IERC165).interfaceId;
    }
}
