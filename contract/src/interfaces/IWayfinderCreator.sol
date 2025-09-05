// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title IWayfinderCreator
 * @author Yigit Duman (@yigitduman)
 */
interface IWayfinderCreator is IERC165 {
    /**
     * @notice Check if an account owns a specific token from a creator contract
     * @param creatorContract The creator contract address to check ownership for
     * @param account The account to check ownership for
     * @param tokenId The token ID to check ownership for
     * @return True if account owns the token, false otherwise
     */
    function isTokenOwner(address creatorContract, address account, uint256 tokenId) external view returns (bool);
}
