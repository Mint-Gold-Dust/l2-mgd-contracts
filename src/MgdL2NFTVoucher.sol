// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {Almost1155Upgradeable} from "./utils/Almost1155Upgradeable.sol";
import {ICrossDomainMessenger} from "./interfaces/ICrossDomainMessenger.sol";
// import {MgdL2NFT} from "./MgdL2NFT.sol";

/// @title MgdL2NFTVoucher
/// @notice This contract "Vouchers" are a representation of an NFT on ethereum mainnet.
/// @author Mint Gold Dust LLC
/// @custom:contact klvh@mintgolddust.io
contract MgdL2NFTVoucher is Almost1155Upgradeable {
  ///Events
  event MintClearance(uint256 indexed voucherId);

  // uint256 voucherId => escrowCleared
  mapping(uint256 => bool) public mintCleared;

  ICrossDomainMessenger public crossDomainMessenger;

  function setMintClearance(uint256 voucherId) external {
    emit MintClearance(voucherId);
  }

  //   /**
  //      * @dev The transfer function wraps the safeTransferFrom function of ERC1155.
  //      * @param from Sender of the token.
  //      * @param to Token destination.
  //      * @param tokenId ID of the token.
  //      * @param amount Amount of tokens to be transferred.
  //      */
  //     function transfer(
  //         address from,
  //         address to,
  //         uint256 tokenId,
  //         uint256 amount
  //     ) external override nonReentrant {
  //         safeTransferFrom(from, to, tokenId, amount, "");
  //     }

  // /**
  //  * Mints a new Mint Gold Dust token.
  //  * @notice Fails if artist is not whitelisted or if the royalty surpass the max royalty limit
  //  * setted on MintGoldDustCompany smart contract.
  //  * @dev tokenIdArtist keeps track of the work of each artist and tokenIdRoyaltyPercent the royalty
  //  * percent for each art work.
  //  * @param _tokenURI The uri of the token metadata.
  //  * @param _royaltyPercent The royalty percentage for this art work.
  //  * @param _amount The amount of tokens to be minted.
  //  */
  // function _executeMintFlow(
  //     string calldata _tokenURI,
  //     uint256 _royaltyPercent,
  //     uint256 _amount,
  //     address _sender,
  //     uint256 _collectorMintId,
  //     bytes calldata _memoir
  // ) internal override isZeroAddress(_sender) returns (uint256) {
  //     _tokenIds.increment();
  //     uint256 newTokenId = _tokenIds.current();
  //     _mint(_sender, newTokenId, _amount, "");
  //     _setURI(newTokenId, _tokenURI);
  //     tokenIdArtist[newTokenId] = _sender;
  //     tokenIdRoyaltyPercent[newTokenId] = _royaltyPercent;
  //     tokenIdMemoir[newTokenId] = _memoir;

  //     primarySaleQuantityToSold[newTokenId] = _amount;

  //     emit MintGoldDustNFTMinted(
  //         newTokenId,
  //         _tokenURI,
  //         _sender,
  //         _royaltyPercent,
  //         _amount,
  //         false,
  //         _collectorMintId,
  //         _memoir
  //     );

  //     return newTokenId;
  // }
}
