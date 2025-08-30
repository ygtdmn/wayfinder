// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/**
 * @title IMultiplexCreator
 * @author Yigit Duman (@yigitduman)
 * @notice Interface for creator contracts that want to delegate admin and ownership checks to themselves
 * @dev This allows creator contracts to define their own logic for determining admins and token owners,
 *      which is especially important for smart wallet compatibility
 */
interface IMultiplexCreator {
    /**
     * @notice Check if an account is an admin of a creator contract
     * @param creatorContract The creator contract address to check admin status for
     * @param account The account to check admin status for
     * @return True if account is admin, false otherwise
     */
    function isContractAdmin(address creatorContract, address account) external view returns (bool);

    /**
     * @notice Check if an account owns a specific token from a creator contract
     * @param creatorContract The creator contract address to check ownership for
     * @param account The account to check ownership for
     * @param tokenId The token ID to check ownership for
     * @return True if account owns the token, false otherwise
     */
    function isTokenOwner(address creatorContract, address account, uint256 tokenId) external view returns (bool);
}
