// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {Script} from "forge-std/Script.sol";
import {ScriptConstants} from "./ScriptConstants.s.sol";
import {console} from "forge-std/console.sol";

contract FileSystem is Script, ScriptConstants {
    function saveAddress(
        string memory contractLabel,
        string memory chainName,
        address addr
    ) public {
        string memory path = getContractLabelPathAt(contractLabel, chainName);
        createAndSaveFile(path, vm.toString(addr));
    }

    function getAddress(
        string memory contractLabel,
        string memory chainName
    ) public view returns (address addr) {
        string memory content = vm.readFile(
            getContractLabelPathAt(contractLabel, chainName)
        );
        addr = vm.parseAddress(content);
    }

    function getContractLabelPathAt(
        string memory contractLabel,
        string memory chainName
    ) public pure returns (string memory path) {
        path = string.concat("deployments/", chainName, "/", contractLabel);
    }

    function createAndSaveFile(
        string memory path,
        string memory content
    ) public {
        try vm.removeFile(path) {} catch {
            console.log(
                string(abi.encodePacked("Creating a new record at ", path))
            );
        }
        vm.writeLine(path, content);
    }

    function vmStartBroadcast() public {
        vm.startBroadcast();
    }

    function vmStopBroadcast() public {
        vm.stopBroadcast();
    }
}
