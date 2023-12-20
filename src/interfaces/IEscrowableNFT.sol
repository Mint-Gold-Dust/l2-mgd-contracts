// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {MgdL1MarketData} from "../abstract/MgdL2Voucher.sol";

interface IEscrowableNFT {
  function permit(bytes calldata params) external payable;

  function transfer(address from, address to, uint256 tokenId, uint256 amount) external;

  function updateMarketData(
    uint256 tokenId,
    MgdL1MarketData calldata marketData,
    bool isL2Native
  )
    external;

  function mintNft(
    string calldata tokenURI,
    uint256 royaltyPercent,
    uint256 amount,
    bytes calldata memoir
  )
    external
    payable
    returns (uint256);
}
