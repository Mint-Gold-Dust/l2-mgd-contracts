// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {MintGoldDustERC721} from "mgd-v2-contracts/MintGoldDustERC721.sol";
import {MgdL2EscrowNFT, NFTEscrowData} from "./MgdL2EscrowNFT.sol";
import {MgdCompanyL2Sync, IL1crossDomainMessenger} from "./MgdCompanyL2Sync.sol";

contract MgdERC721Escrowable is MintGoldDustERC721, MgdL2EscrowNFT {
  /// errors
  error MgdERC721Escrowable__placeIntoEscrow_notOwner();
  error MgdERC721Escrowable__beforeTransfer_NFTisInEscrow();

  function placeIntoEscrow(
    uint256 tokenId,
    uint256 /*amount*/
  )
    external
    override
    returns (bytes32 voucherIdL2)
  {
    address owner = _ownerOf(tokenId);
    if (msg.sender != owner || owner == address(0)) {
      revert MgdERC721Escrowable__placeIntoEscrow_notOwner();
    }

    voucherIdL2 = _generateVoucherId(tokenId, 1, owner);
    NFTEscrowData memory escrowData = NFTEscrowData(1, voucherIdL2);
    escrowedTokenId[tokenId] = escrowData;

    _sendL2EscrowNotice(address(this), tokenId, 1, voucherIdL2);
    emit EnterEscrow(tokenId, 1);
  }

  function placeIntoEscrow(
    uint256 tokenId,
    uint256, /*amount*/
    uint256 deadline,
    bytes memory ownerSignature
  )
    external
    override
    returns (bytes32 voucherIdL2)
  {
    _checkSignature(tokendId, deadline, ownerSignature);

    voucherIdL2 = _generateVoucherId(tokenId, 1, owner);
    NFTEscrowData memory escrowData = NFTEscrowData(1, voucherIdL2);
    escrowedTokenId[tokenId] = escrowData;

    _sendL2EscrowNotice(address(this), tokenId, 1, voucherIdL2);
    emit EnterEscrow(tokenId, 1);
  }

  function releaseFromEscrow(uint256 tokenId, uint256 amount) external override {}

  function updateEscrowedOwner(uint256 tokenId, address newOwner) external override {}

  function _checkSignature(
    uint256 tokenId,
    uint256 deadline,
    bytes memory signature
  )
    private
  {
    address realOwner = _ownerOf(tokenId);
    bytes32 structHash =
      keccak256(abi.encode(_PLACE_INTO_ESCROW_TYPEHASH, tokenId, 1, _useNonce(realOwner), deadline));
    bytes32 digest = _hashTypedDataV4(structHash);
    pressumed = ECDSAUpgradeable.recover(digest, signature);
    if (pressumedOwner != realOwner) {
      revert MgdERC721Escrowable__checkSignature_notOwner();
    }
  }

  function _sendL2EscrowNotice(
    address nft,
    uint256 tokenId,
    uint256 amount,
    bytes32 voucherId
  )
    internal
    override
    isZeroAddress(nftL2Voucher)
  {
    bytes memory message = abi.encodeWithSignature(
      "setEscrowedConfirmed(address,uint256,uint256,bytes32)", nft, tokenId, amount, voucherId
    );
    IL1crossDomainMessenger(address(mintGoldDustCompany)).sendMessage(
      nftL2Voucher, message, 1000000
    );
  }

  function _beforeTokenTransfer(
    address, /*from*/
    address, /*to*/
    uint256 firstTokenId,
    uint256 /*batchSize*/
  )
    internal
    view
    override
  {
    if (escrowedTokenId[firstTokenId].amount > 0) {
      revert MgdERC721Escrowable__beforeTransfer_NFTisInEscrow();
    }
  }
}
