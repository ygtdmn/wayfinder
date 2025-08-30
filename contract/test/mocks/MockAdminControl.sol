// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

import { IMultiplexCreator } from "src/interfaces/IMultiplexCreator.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title MockAdminControl
 * @dev Simple mock implementation that provides isAdmin functionality for testing
 */
contract MockAdminControl is IMultiplexCreator {
    mapping(address => bool) private _admins;
    address private _owner;

    constructor() {
        _owner = msg.sender;
        _admins[msg.sender] = true;
    }

    function isAdmin(address admin) external view returns (bool) {
        return _admins[admin];
    }

    function approveAdmin(address admin) external {
        require(msg.sender == _owner, "Only owner can approve admin");
        _admins[admin] = true;
    }

    function revokeAdmin(address admin) external {
        require(msg.sender == _owner, "Only owner can revoke admin");
        _admins[admin] = false;
    }

    function isTokenOwner(
        address /* creatorContract */,
        address /* account */,
        uint256 /* tokenId */
    ) external pure override returns (bool) {
        // MockAdminControl doesn't have actual token ownership, so return false
        return false;
    }

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IMultiplexCreator).interfaceId || interfaceId == type(IERC165).interfaceId;
    }
}
