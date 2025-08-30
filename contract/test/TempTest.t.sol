// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

import "forge-std/src/Test.sol";
import { IERC1155CreatorCore } from "@manifoldxyz/creator-core-solidity/contracts/core/IERC1155CreatorCore.sol";
import { console2 } from "forge-std/src/console2.sol";
import { MultiplexManifoldExtension } from "src/MultiplexManifoldExtension.sol";
import { Multiplex } from "src/Multiplex.sol";
import { IMultiplex } from "src/interfaces/IMultiplex.sol";
import { IERC1155MetadataURI } from "@openzeppelin/contracts/interfaces/IERC1155MetadataURI.sol";
import { IAdminControl } from "@manifoldxyz/libraries-solidity/contracts/access/IAdminControl.sol";
import { Ownable } from "solady/auth/Ownable.sol";

contract TempTest is Test {
    Multiplex multiplex;

    error WalletNotAdmin();

    function setUp() public {
        vm.startPrank(address(0x01), address(0x01));
        multiplex = new Multiplex("<html>{{FILE_URIS}}</html>", false);
        vm.stopPrank();
    }

    function testTest() external {
        vm.startPrank(address(0x01), address(0x01));
        require(_isContractAdmin(address(multiplex), address(0x01)), WalletNotAdmin());
        vm.stopPrank();
    }

    /// @notice Check if account is owner/admin of a contract using fallback methods
    /// @param contractAddress The contract to check
    /// @param account The account to check
    /// @return True if account is owner/admin
    function _isContractAdmin(address contractAddress, address account) internal view returns (bool) {
      console2.log("contractAddress", contractAddress);
      console2.log("account", account);
        (bool ok, bytes memory ret) =
            contractAddress.staticcall(abi.encodeWithSelector(IAdminControl.isAdmin.selector, account));
        console2.log("ok", ok);
        console2.logBytes(ret);
        if (ok && ret.length >= 32) {
            return abi.decode(ret, (bool));
        }
        (ok, ret) = contractAddress.staticcall(abi.encodeWithSelector(Ownable.owner.selector));
        console2.log("ok", ok);
        console2.logBytes(ret);
        if (ok && ret.length >= 32) {
            console2.log("owner", abi.decode(ret, (address)));
            return abi.decode(ret, (address)) == account;
        }
        return false;
    }
}
