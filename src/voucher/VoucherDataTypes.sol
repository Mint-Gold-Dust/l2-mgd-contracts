// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {ManageSecondarySale} from "mgd-v2-contracts/MintGoldDustMarketplace.sol";

enum TypeNFT {
  ERC721,
  ERC1155
}

struct MgdL1MarketData {
  address artist;
  bool hasCollabs;
  bool tokenWasSold;
  uint40 collabsQuantity;
  uint40 primarySaleQuantityToSell;
  uint256 royaltyPercent;
  address[4] collabs;
  uint256[5] collabsPercentage;
  ManageSecondarySale secondarySaleData;
}

struct L1VoucherData {
  address nft;
  uint256 tokenId;
  uint256 representedAmount;
}
