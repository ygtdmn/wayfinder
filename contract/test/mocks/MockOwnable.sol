// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

import { Ownable } from "solady/auth/Ownable.sol";
import { IWayfinderCreator } from "src/interfaces/IWayfinderCreator.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

contract MockOwnable is Ownable, IWayfinderCreator {
    constructor(address _owner) {
        _initializeOwner(_owner);
    }

    function isTokenOwner(
        address /* creatorContract */,
        address /* account */,
        uint256 /* tokenId */
    ) external pure override returns (bool) {
        // MockOwnable doesn't have actual token ownership, so return false
        return false;
    }

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IWayfinderCreator).interfaceId || interfaceId == type(IERC165).interfaceId;
    }
}
