// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

import { Ownable } from "solady/auth/Ownable.sol";

contract MockOwnable is Ownable {
    constructor(address _owner) {
        _initializeOwner(_owner);
    }
}
