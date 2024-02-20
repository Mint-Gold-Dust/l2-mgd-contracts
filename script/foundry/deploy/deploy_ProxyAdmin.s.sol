// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {console} from "forge-std/console.sol";
import {FileSystem} from "../utils/FileSystem.s.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

library ProxyAdminDeployer {
    function deployProxyAdmin(FileSystem fs) internal returns (ProxyAdmin) {
        string memory chainName = fs.getChainName(block.chainid);

        console.log("Deploying ProxyAdmin...");
        ProxyAdmin proxyAdmin = new ProxyAdmin();
        console.log("ProxyAdmin {ProxyAdmin}:", address(proxyAdmin));

        fs.saveAddress("ProxyAdmin", chainName, address(proxyAdmin));
        console.log("Saved ProxyAdmin:", address(proxyAdmin));
        return proxyAdmin;
    }
}
