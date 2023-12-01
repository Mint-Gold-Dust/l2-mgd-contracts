// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {MintGoldDustERC721, MintGoldDustCompany} from "mgd-v2-contracts/MintGoldDustERC721.sol";
import {MgdL2EscrowNFT} from "./MgdL2EscrowNFT.sol";

contract MgdERC721Escrowable is MintGoldDustERC721, MgdL2EscrowNFT {
  /// errors
  error MgdERC721Escrowable__placeIntoEscrow_notOwner();
  error MgdERC721Escrowable__beforeTransfer_NFTisInEscrow();

  function placeIntoEscrow(
    uint256 tokenId,
    uint256 /*amount*/
  )
    public
    override
    returns (bytes32 voucherIdL2)
  {
    address owner = _ownerOf(tokenId);
    if (msg.sender != owner || owner == address(0)) {
      revert MgdERC721Escrowable__placeIntoEscrow_notOwner();
    }

    voucherIdL2 = _generateVoucherId(token, 1, owner);
    NFTEscrowData memory escrowData = NFTEscrowData(1, voucherIdL2);
    escrowedTokenId[tokenId] = escrowData;

    emit EnterEscrow(tokenId, 1);
  }

  function _beforeTokenTransfer(
    address, /*from*/
    address, /*to*/
    uint256 firstTokenId,
    uint256 /*batchSize*/
  )
    internal
    override
  {
    if (escrowedTokenId[firstTokenId].amount > 0) {
      revert MgdL2EscrowNFT_NFTisInEscrow();
    }
  }
}
