// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

/// @title MGDL2EscrowNFT
/// @notice Escrow contract that holds an NFT due to activity in a L2.
/// @author Mint Gold Dust LLC
/// @custom:contact klvh@mintgolddust.io
contract MgdL2NFTEscrow is Initializable, IERC721Receiver, IERC1155Receiver {
  /// events
  event EnterEscrow(address indexed nftcontract, uint256 indexed tokenId, uint256 amount);
  event ReleasedEscrow(address indexed nftcontract, uint256 indexed tokenId, uint256 amount);

  // bytes4 private constant
  //     _IERC1155_ONRECEIVED = bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
  bytes4 private constant _IERC1155_ONRECEIVED = 0xf23a6e61;

  address public mgdERC721;
  address public mgdERC1155;
  address public nftL2Voucher;

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
   */
  uint256[50] private __gap;

  /**
   * @param nft contract
   * @param tokenId of the nft
   * @param amount of tokenId
   * @param deadline expiration of the attached signature
   * @param signature of the `_PLACE_INTO_ESCROW_TYPEHASH`
   * @dev Requirements:
   * - `signature` must be done by the current owner of `tokenId`.
   */
  function placeIntoEscrow(
    address nft,
    uint256 tokenId,
    uint256 amount,
    uint256 deadline,
    bytes memory signature
  )
    external
    override
    returns (uint256 voucherId)
  {
    // address signer = _getSigner(nft, tokendId, amount, deadline, signature);

    // voucherIdL2 = _generateVoucherId(signature);
    // NFTEscrowData memory escrowData = NFTEscrowData(1, voucherIdL2);
    // escrowedTokenId[tokenId] = escrowData;

    // _sendL2EscrowNotice(address(this), tokenId, 1, voucherIdL2);
    // emit EnterEscrow(tokenId, 1);
  }

  /**
   * @dev Requirements:
   * - Must be called by {MgdCompanyL2Sync.crossDomainMessenger}
   */
  function releaseFromEscrow(uint256 tokenId, uint256 amount) external virtual;

  function onERC721Received(
    address operator,
    address from,
    uint256 id,
    bytes calldata data
  )
    external
    returns (bytes4)
  {
    IERC721 nft = IERC721(msg.sender);
    if (nft.ownerOf(id) == address(this)) {
      emit EnterEscrow(address(nft), id, 1);
    }
  }

  function onERC1155Received(
    address operator,
    address from,
    uint256 id,
    uint256 value,
    bytes calldata data
  )
    external
    override
    returns (bytes4)
  {
    IERC1155 nft = IERC1155(msg.sender);
    if (nft.balanceOf(address(this), id) == value) {
      emit EnterEscrow(address(nft), id, value);
      return _IERC1155_ONRECEIVED;
    }
  }

  function onERC1155BatchReceived(
    address operator,
    address from,
    uint256[] calldata ids,
    uint256[] calldata values,
    bytes calldata data
  )
    external
    returns (bytes4)
  {
    IERC1155 nft = IERC1155(msg.sender);
    uint256 len = ids.length;
    uint256 counted;
    for (uint256 i = 0; i < len; i++) {
      if (nft.balanceOf(address(this), ids[i]) == values[i]) {
        emit EnterEscrow(address(nft), ids[i], values[i]);
        counted++;
      }
    }
    if (counted == len) {
      return _IERC1155_ONRECEIVED;
    }
  }

  function _getSigner(
    address nft,
    uint256 tokenId,
    uint256 amount,
    uint256 deadline,
    bytes memory signature
  )
    private
    pure
    returns (address pressumed)
  {
    // bytes32 structHash = keccak256(
    //   abi.encode(
    //     _PLACE_INTO_ESCROW_TYPEHASH, nft, tokenId, amount, _useNonce(nft, tokenId), deadline
    //   )
    // );
    // bytes32 digest = _hashTypedDataV4(structHash);
    // pressumed = ECDSA.recover(digest, signature);
  }

  function _generateVoucherId(bytes memory signature) internal view returns (bytes32) {
    return keccak256(signature);
  }

  function _sendL2EscrowNotice(
    address nft,
    uint256 tokenId,
    uint256 amount,
    bytes32 voucherId
  )
    internal
  {
    // bytes memory message = abi.encodeWithSignature(
    //   "setEscrowedConfirmed(address,uint256,uint256,bytes32)", nft, tokenId, amount, voucherId
    // );
    // IL1crossDomainMessenger(address(mintGoldDustCompany)).sendMessage(
    //   nftL2Voucher, message, 1000000
    // );
  }
}
