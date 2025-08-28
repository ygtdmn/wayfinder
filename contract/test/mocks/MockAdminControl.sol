// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/**
 * @title MockAdminControl
 * @dev Simple mock implementation that provides isAdmin functionality for testing
 */
contract MockAdminControl {
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
}
