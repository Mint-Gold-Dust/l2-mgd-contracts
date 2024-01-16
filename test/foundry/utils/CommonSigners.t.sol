// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {Test} from "forge-std/Test.sol";
import {VmSafe} from "forge-std/StdUtils.sol";

contract CommonSigners is Test {
  // OP stack test constants
  VmSafe.Wallet public Alice;
  VmSafe.Wallet public Bob;
  VmSafe.Wallet public Charlie;
  VmSafe.Wallet public David;
  VmSafe.Wallet public MGDSigner;

  constructor() {
    Alice = vm.createWallet("Alice");
    Bob = vm.createWallet("Bob");
    Charlie = vm.createWallet("Charlie");
    David = vm.createWallet("David");
    MGDSigner = vm.createWallet("MgdSigner");
  }
}
