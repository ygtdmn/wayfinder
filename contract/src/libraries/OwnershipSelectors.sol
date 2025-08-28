// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

/**
 * @title OwnershipSelectors
 * @notice Common function selectors for ownership checks
 * @dev These are provided for convenience when configuring ownership checks
 */
library OwnershipSelectors {
    bytes4 public constant OWNER_OF = 0x6352211e; // ownerOf(uint256)
    bytes4 public constant BALANCE_OF_ERC1155 = 0x00fdd58e; // balanceOf(address,uint256)
}
