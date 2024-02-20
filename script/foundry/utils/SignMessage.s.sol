// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {VmSafe} from "forge-std/StdUtils.sol";
import {Test} from "forge-std/Test.sol";

import {console} from "forge-std/console.sol";

contract SignMessage is Test {
  uint256 private constant PK = 0xba3d712e1c54ecf154228afffa573e332884eec47cfb6399a6d5c86f721e7887;
  bytes32 private constant DIGEST =
    0x73f2caa7f6b08fcf10d7e4d1c9bac8beae69b450c9f037a78d0becd3d6f4f790;

  function run() public view {
    bytes memory signature = signMessage(DIGEST, PK);
    console.log("Signature:");
    console.logBytes(signature);
  }

  function signMessage(bytes32 digest, uint256 privateKey) public pure returns (bytes memory) {
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
    return abi.encodePacked(r, s, v);
  }
}
