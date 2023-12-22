// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {Test} from "forge-std/Test.sol";
import {MockCrossDomainMessenger as CDMessenger} from "../../mocks/MockCrossDomainMessenger.sol";

contract BaseL2Constants is Test {
  // events
  event SentMessage(
    address indexed target, address sender, bytes message, uint256 messageNonce, uint256 gasLimit
  );

  // OP stack test constants
  address internal constant L1_CROSSDOMAIN_MESSENGER = 0x866E82a600A1414e583f7F13623F1aC5d58b0Afa; //mainnet
  address internal constant L2_CROSSDOMAIN_MESSENGER = 0x4200000000000000000000000000000000000007; // base

  constructor() {
    deployCodeTo("MockCrossDomainMessenger.sol", L1_CROSSDOMAIN_MESSENGER);
    deployCodeTo("MockCrossDomainMessenger.sol", L2_CROSSDOMAIN_MESSENGER);
  }
}
