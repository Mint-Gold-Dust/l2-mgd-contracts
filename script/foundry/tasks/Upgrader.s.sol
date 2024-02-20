// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {console} from "forge-std/console.sol";
import {FileSystem} from "../utils/FileSystem.s.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {ITransparentUpgradeableProxy} from
  "../../../src/utils/openzeppelin/TransparentUpgradeableProxy.sol";

library Upgrader {
  function upgrade(FileSystem fs, address proxy, address newImplementation) internal {
    string memory chainName = fs.getChainName(block.chainid);
    ProxyAdmin proxyAdmin;
    try fs.getAddress("ProxyAdmin", chainName) returns (address addr) {
      proxyAdmin = ProxyAdmin(addr);
    } catch {
      revert("ProxyAdmin not found");
    }
    proxyAdmin.upgrade(ITransparentUpgradeableProxy(proxy), newImplementation);
    console.log("Succesfully upgraded proxy", proxy);
  }
}
