// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

contract MgdScriptConstants {
  uint256 internal constant _PRIMARY_SALE_FEE_PERCENT = 15e18;
  uint256 internal constant _SECONDARY_SALE_FEE_PERCENT = 5e18;
  uint256 internal constant _COLLECTOR_FEE = 3e18;
  uint256 internal constant _MAX_ROYALTY = 20e18;
  uint256 internal constant _AUCTION_DURATION = 1 days;
  uint256 internal constant _AUCTION_EXTENSION = 5 minutes;

  string internal constant _BASE_URI = "https://www.mintgolddust.com/";

  address internal constant _MGD_SIGNER = 0x97d35f7dA031e3568d4528C04d5F498E3c3Dee70;
}
