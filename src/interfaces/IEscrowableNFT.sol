// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

interface IEscrowableNFT {
  function permit(bytes calldata params) external payable;

  function transfer(address from, address to, uint256 tokenId, uint256 amount) external;
}
