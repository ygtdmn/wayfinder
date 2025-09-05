// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { IWayfinderCreator } from "src/interfaces/IWayfinderCreator.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

contract MockERC721 is ERC721, IWayfinderCreator {
    uint256 private _nextTokenId = 1;
    mapping(address => bool) private _admins;
    address private _owner;

    constructor() ERC721("Test", "TEST") {
        _owner = msg.sender;
        _admins[msg.sender] = true;
    }

    function mint(address to) external returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _mint(to, tokenId);
        return tokenId;
    }

    function isAdmin(address account) external view returns (bool) {
        return _admins[account];
    }

    function owner() external view returns (address) {
        return _owner;
    }

    function setAdmin(address account, bool adminStatus) external {
        require(_admins[msg.sender], "Not admin");
        _admins[account] = adminStatus;
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
        if (creatorContract == address(this)) {
            try this.ownerOf(tokenId) returns (address tokenOwner) {
                return tokenOwner == account;
            } catch {
                return false;
            }
        }
        return false;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, IERC165) returns (bool) {
        return interfaceId == type(IWayfinderCreator).interfaceId || super.supportsInterface(interfaceId);
    }
}
