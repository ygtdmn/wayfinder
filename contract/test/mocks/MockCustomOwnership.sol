// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/**
 * @title MockCustomOwnership
 * @dev Mock contract for testing custom ownership styles in Multiplex
 */
contract MockCustomOwnership {
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
}
