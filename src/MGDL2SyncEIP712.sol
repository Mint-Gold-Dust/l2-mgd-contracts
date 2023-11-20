// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

contract MGDL2SyncEIP712 {
  bytes32 private constant SETVALIDATOR_TYPEHASH =
    keccak256("SetValidator(address _address,bool _state)");
}
