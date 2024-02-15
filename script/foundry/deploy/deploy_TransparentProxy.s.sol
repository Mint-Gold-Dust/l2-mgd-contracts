// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {console} from "forge-std/console.sol";
import {FileSystem} from "../utils/FileSystem.s.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "../../../src/utils/openzeppelin/TransparentUpgradeableProxy.sol";

library TransparentProxyDeployer {
    function deployTransparentProxy(
        FileSystem fs,
        address proxyAdmin,
        address implementation,
        bytes memory initData,
        string memory contractLabel
    ) internal returns (address) {
        string memory chainName = fs.getChainName(block.chainid);

        address proxy;
        bytes memory contructorArgs = abi.encode(
            implementation,
            proxyAdmin,
            initData
        );
        console.log("TransparentUpgradeableProxy constructor arguments:");
        console.logBytes(contructorArgs);

        proxy = address(
            new TransparentUpgradeableProxy(
                implementation,
                proxyAdmin,
                initData
            )
        );

        console.log("TransparentUpgradeableProxy deployed:", proxy);
        fs.saveAddress(contractLabel, chainName, proxy);
        return proxy;
    }
}
