// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

enum TypeNFT {
  ERC721,
  ERC1155
}

struct MgdL1MarketData {
  address artist;
  bool hasCollabs;
  bool tokenWasSold;
  uint40 collabsQuantity;
  uint40 primarySaleL2QuantityToSell;
  uint256 royaltyPercent;
  address[4] collabs;
  uint256[5] collabsPercentage;
}

struct L1VoucherData {
  address nft;
  uint256 tokenId;
  uint256 representedAmount;
}
