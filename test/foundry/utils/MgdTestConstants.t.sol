// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

contract MgdTestConstants {
  // Test ChainIds
  uint256 internal constant _ETHEREUM_CHAIN_ID = 1;
  uint256 internal constant _TEST_CHAIN_ID = 31337;

  // MgdCompanyL2Sync.initializer test constants
  uint256 internal constant _PRIMARY_SALE_FEE_PERCENT = 15e18;
  uint256 internal constant _SECONDARY_SALE_FEE_PERCENT = 5e18;
  uint256 internal constant _COLLECTOR_FEE = 3e18;
  uint256 internal constant _MAX_ROYALTY = 20e18;
  uint256 internal constant _AUCTION_DURATION = 1 days;
  uint256 internal constant _AUCTION_EXTENSION = 5 minutes;
}
