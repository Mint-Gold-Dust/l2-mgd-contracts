// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {MgdL1MarketData} from "../voucher/VoucherDataTypes.sol";

interface IEscrowableNFT {
  function permit(bytes calldata params) external payable;

  function transfer(address from, address to, uint256 tokenId, uint256 amount) external;

  function updateMarketData(uint256 tokenId, MgdL1MarketData calldata marketData) external;

  function mintFromL2Native(
    address receiver,
    uint256 amount,
    MgdL1MarketData calldata marketData,
    string calldata tokenURI,
    bytes calldata memoir
  )
    external
    returns (uint256 newTokenId);
}
