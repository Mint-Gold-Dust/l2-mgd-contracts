// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IEscrowableNFT} from "./interfaces/IEscrowableNFT.sol";
import {ICrossDomainMessenger} from "./interfaces/ICrossDomainMessenger.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {MgdL1NFTData} from "./MgdL2NFT.sol";
import {MgdL2NFTVoucher} from "./MgdL2NFTVoucher.sol";

/// @title MGDL2EscrowNFT
/// @notice Escrow contract that holds an NFT due to activity in a L2.
/// @author Mint Gold Dust LLC
/// @custom:contact klvh@mintgolddust.io
/// @dev This contract is meant to be deployed on the L1.
contract MgdL2NFTEscrow is Initializable, IERC721Receiver, IERC1155Receiver {
  /// events
  event EnterEscrow(
    address indexed nftcontract,
    uint256 indexed tokenId,
    uint256 amount,
    address owner,
    bytes32 blockHash,
    MgdL1NFTData tokenData,
    uint256 indexed identifier
  );
  event ReleasedEscrow(
    address indexed nftcontract, uint256 indexed tokenId, uint256 indexed identifier, uint256 amount
  );

  bytes4 private constant _EMPTY_BYTES4 = 0x00000000;

  ICrossDomainMessenger public crossDomainMessenger;
  address public mgdL2Voucher;

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
   */
  uint256[50] private __gap;

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
    return interfaceId == type(IERC721Receiver).interfaceId
      || interfaceId == type(IERC1155Receiver).interfaceId;
  }

  /**
   * @param nft contract
   * @param tokenId to be moved into escrow
   * @param owner current owner of tokenId
   * @param amount of tokenId
   * @param deadline expiration of the attached signature
   * @param signature to be used in {nft.permit(...)}
   * @dev Requirements:
   * - `signature` must be done by the current owner of `tokenId`.
   */
  function moveToEscrowOnBehalf(
    address nft,
    address owner,
    uint256 tokenId,
    uint256 amount,
    uint256 deadline,
    bytes calldata signature
  )
    external
  {
    (uint8 v, bytes32 r, bytes32 s) = _getSignatureValues(signature);
    IEscrowableNFT(nft).permit(abi.encode(owner, address(this), tokenId, amount, deadline, v, r, s));
    IEscrowableNFT(nft).transfer(owner, address(this), tokenId, amount);
  }

  /**
   * @dev Requirements:
   * - Must be called by {MgdCompanyL2Sync.crossDomainMessenger}
   */
  function releaseFromEscrow(uint256 tokenId, uint256 amount) external {
    // TODO
  }

  function onERC721Received(
    address, // operator
    address from,
    uint256 tokenId,
    bytes calldata data
  )
    external
    returns (bytes4)
  {
    IERC721 nft = IERC721(msg.sender);
    _checkDataNonZero(data);
    MgdL1NFTData memory tokenData = abi.decode(data, (MgdL1NFTData));
    if (nft.ownerOf(tokenId) == address(this)) {
      (uint256 identifier, bytes32 blockHash) =
        _generateUniqueIdentifier(address(nft), tokenId, 1, from, tokenData);

      _sendEscrowNoticeToL2(identifier);

      emit EnterEscrow(address(nft), tokenId, 1, from, blockHash, tokenData, identifier);
      return this.onERC721Received.selector;
    } else {
      return _EMPTY_BYTES4;
    }
  }

  function onERC1155Received(
    address, // operator
    address from,
    uint256 tokenId,
    uint256 amount,
    bytes calldata data
  )
    external
    override
    returns (bytes4)
  {
    IERC1155 nft = IERC1155(msg.sender);
    _checkDataNonZero(data);
    MgdL1NFTData memory tokenData = abi.decode(data, (MgdL1NFTData));
    /**
     * @dev TODO confirm if the below check is safe, given there could be
     * tokenIds of the same contract already in escrow.
     */
    if (nft.balanceOf(address(this), tokenId) >= amount) {
      (uint256 identifier, bytes32 blockHash) =
        _generateUniqueIdentifier(address(nft), tokenId, amount, from, tokenData);

      _sendEscrowNoticeToL2(identifier);

      emit EnterEscrow(address(nft), tokenId, amount, from, blockHash, tokenData, identifier);
      return this.onERC1155Received.selector;
    } else {
      return _EMPTY_BYTES4;
    }
  }

  function onERC1155BatchReceived(
    address, // operator
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
    MgdL1NFTData[] memory datas = abi.decode(data, (MgdL1NFTData[]));
    for (uint256 i = 0; i < len; i++) {
      /**
       * @dev TODO confirm if the below check is safe, given there could be
       * tokenIds of the same contract already in escrow.
       */
      if (nft.balanceOf(address(this), ids[i]) >= values[i]) {
        (uint256 identifier, bytes32 blockHash) =
          _generateUniqueIdentifier(address(nft), ids[i], values[i], from, datas[i]);

        _sendEscrowNoticeToL2(identifier);

        emit EnterEscrow(address(nft), ids[i], values[i], from, blockHash, datas[i], identifier);
        counted++;
      }
    }
    if (counted == len) {
      return this.onERC1155Received.selector;
    } else {
      return _EMPTY_BYTES4;
    }
  }

  /**
   * @dev Returns signature v, r, s values.
   *
   * @param signature abi.encodePacked(r,s,v)
   */
  function _getSignatureValues(bytes memory signature)
    private
    pure
    returns (uint8 v, bytes32 r, bytes32 s)
  {
    if (signature.length == 65) {
      // ecrecover takes the signature parameters, and the only way to get them
      // currently is to use assembly.
      /// @solidity memory-safe-assembly
      assembly {
        r := mload(add(signature, 0x20))
        s := mload(add(signature, 0x40))
        v := byte(0, mload(add(signature, 0x60)))
      }
    } else {
      revert("Wrong signature size");
    }
  }

  function _generateUniqueIdentifier(
    address nft,
    uint256 tokenId,
    uint256 amount,
    address owner,
    MgdL1NFTData memory tokenData
  )
    internal
    view
    returns (uint256 identifier, bytes32 blockHash)
  {
    blockHash = blockhash(block.number);
    identifier = uint256(keccak256(abi.encode(nft, tokenId, amount, owner, blockHash, tokenData)));
  }

  function _checkDataNonZero(bytes memory data) internal pure virtual {
    if (data.length == 0) {
      revert("Wrong data size");
    }
  }

  function _sendEscrowNoticeToL2(uint256 voucherId) internal {
    bytes memory message =
      abi.encodeWithSelector(MgdL2NFTVoucher.setMintClearance.selector, voucherId);
    crossDomainMessenger.sendMessage(mgdL2Voucher, message, 1000000);
  }
}
