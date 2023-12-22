// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {Test} from "forge-std/Test.sol";

contract Helpers is Test {
  function generate_packedSignature(
    bytes32 digest,
    uint256 signerPrivKey
  )
    internal
    pure
    returns (bytes memory signature)
  {
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivKey, digest);
    return abi.encodePacked(r, s, v);
  }

  function generate_valuesSignature(
    bytes32 digest,
    uint256 signerPrivKey
  )
    internal
    pure
    returns (uint8 v, bytes32 r, bytes32 s)
  {
    (v, r, s) = vm.sign(signerPrivKey, digest);
  }
}
