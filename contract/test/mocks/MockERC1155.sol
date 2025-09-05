// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import { IWayfinderCreator } from "src/interfaces/IWayfinderCreator.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

contract MockERC1155 is ERC1155, IWayfinderCreator {
    mapping(address => bool) private _admins;
    address private _owner;

    constructor() ERC1155("https://test.com") {
        _owner = msg.sender;
        _admins[msg.sender] = true;
    }

    function mint(address to, uint256 id, uint256 amount) external {
        _mint(to, id, amount, "");
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
            return balanceOf(account, tokenId) > 0;
        }
        return false;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155, IERC165) returns (bool) {
        return interfaceId == type(IWayfinderCreator).interfaceId || super.supportsInterface(interfaceId);
    }
}
