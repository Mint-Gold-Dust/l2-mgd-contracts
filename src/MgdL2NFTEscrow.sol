// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {CommonCheckers} from "./utils/CommonCheckers.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IEscrowableNFT} from "./interfaces/IEscrowableNFT.sol";
import {ICrossDomainMessenger} from "./interfaces/ICrossDomainMessenger.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {MgdL2BaseVoucher as MgdL2NFTVoucher} from "./voucher/MgdL2BaseVoucher.sol";
import {MgdCompanyL2Sync} from "./MgdCompanyL2Sync.sol";
import {MgdL1MarketData, TypeNFT} from "./voucher/VoucherDataTypes.sol";
import {MgdEIP712Esrcrow} from "./utils/MgdEIP712Esrcrow.sol";

/// @title MGDL2EscrowNFT
/// @notice Escrow contract that holds an NFT due to activity in a L2.
/// @author Mint Gold Dust LLC
/// @custom:contact klvh@mintgolddust.io
/// @dev This contract is meant to be deployed on the L1.
contract MgdL2NFTEscrow is Initializable, IERC721Receiver, IERC1155Receiver, MgdEIP712Esrcrow {
  /// Events

  /// @dev Emit when NFT is placed into escrow. This event data is used to mint the voucher in the L2.
  event EnterEscrow(
    address nftcontract,
    uint256 indexed tokenId,
    uint256 amount,
    address indexed owner,
    bytes32 blockHash,
    MgdL1MarketData marketData,
    uint256 indexed voucherId
  );

  /// @dev Emit when `setRedeemClearanceKey()` is called.
  event RedeemClearanceKey(uint256 indexed key, bool state);

  /// @dev Emit when NFT is released from escrow.
  event ReleasedEscrow(
    address indexed receiver,
    address nftcontract,
    uint256 indexed tokenId,
    uint256 amount,
    uint256 indexed voucherId,
    uint256 key
  );
  /// @dev Emit when `_setMessenger()` is called.
  event SetMessenger(address messenger);
  /// @dev Emit when `_setVoucherL2()` is called.
  event SetVoucherL2(address newVoucher, TypeNFT nftType);

  /// Custom Errors

  error MgdL2NFTEscrow__onlyCrossAuthorized_notAllowed();
  error MgdL2NFTEscrow__onERC1155BatchReceived_notSupported();
  error MgdL2NFTEscrow__releaseFromEscrow_notClearedOrAlreadyReleased();
  error MgdL2NFTEscrow__releaseFromEscrow_useCreateAndReleaseFromEscrow();
  error MgdL2NFTEscrow__createAndReleaseFromEscrow_wrongInputs();
  error MgdL2NFTEscrow__setVoucherL2_notAllowed();
  error MgdL2NFTEscrow__setVoucherL2_invalidSignature();
  error MgdL2NFTEscrow___setRedeemClearance_burnedReleaseKey();

  bytes4 private constant _EMPTY_BYTES4 = 0x00000000;
  uint256 private constant _REF_NUMBER =
    0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa;

  MgdCompanyL2Sync internal _mgdCompany;

  /// @dev Mapping set from L2 to identify clearance key to release nft from escrow.
  /// uint256 releaseKey => bool cleared
  mapping(uint256 => bool) public redeemClearance;

  ICrossDomainMessenger public messenger;

  address public voucher721L2;
  address public voucher1155L2;

  mapping(uint256 => bool) public burnedReleaseKey;
  mapping(uint256 => uint256) public recordedVoucherIdToTokenIds;

  /**
   * ///@dev This empty reserved space is put in place to allow future versions to add new
   * ///variables without shifting down storage in the inheritance chain.
   * ///See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
   */
  uint256[48] private __gap;

  modifier onlyCrossAuthorized() {
    if (msg.sender != address(messenger) && msg.sender != address(_mgdCompany)) {
      revert MgdL2NFTEscrow__onlyCrossAuthorized_notAllowed();
    }
    _;
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /// @dev Initializes the contract
  function initialize(address mgdCompanyL2Sync) external initializer {
    CommonCheckers.checkZeroAddress(mgdCompanyL2Sync);
    _mgdCompany = MgdCompanyL2Sync(mgdCompanyL2Sync);
    ICrossDomainMessenger crossmessenger = _mgdCompany.messenger();
    _setMessenger(address(crossmessenger));
  }

  function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
    return interfaceId == type(IERC721Receiver).interfaceId
      || interfaceId == type(IERC1155Receiver).interfaceId;
  }

  /// @dev Requirements:
  /// - `signature` must be done by the current owner of `tokenId`.
  /// @param nft contract
  /// @param tokenId to be moved into escrow
  /// @param owner current owner of tokenId
  /// @param amount of tokenId
  /// @param deadline expiration of the attached signature
  /// @param signature to be used in {nft.permit(...)}
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

  ///@notice Called by authorized cross domain messenger to clear release of escrowed NFT.
  function setRedeemClearanceKey(uint256 key, bool state) external onlyCrossAuthorized {
    _setRedeemClearance(key, state);
  }

  /**
   * @notice Set redeem clearance with an authorized signature
   */
  function setRedeemClearanceKeyWithSignature(
    address receiver,
    uint256 key,
    bool state,
    uint256 deadline,
    bytes memory signature
  )
    public
  {
    _checkDeadline(deadline);
    bytes32 structHash = keccak256(
      abi.encode(_SETCLEARANCE_TYPEHASH, receiver, key, state, _useNonce(receiver), deadline)
    );
    bool success = _verifySignature(_mgdCompany.publicKey(), structHash, signature);
    if (success) {
      _setRedeemClearance(key, state);
    } else {
      revert MgdL2NFTEscrow__setVoucherL2_invalidSignature();
    }
  }

  /// @notice Returns the expected release key.
  /// The Input data can be obtained from event when calling {MgdL2Voucher.redeemVoucherToL1(...)} in L2.
  /// @param voucherId used as voucherId in L2 voucher contract
  /// @param nft token address to redeem
  /// @param tokenId  to redeeem
  /// @param amount to redeem
  /// @param receiver who will receive nft
  /// @param blockHash of tx in L2 where {MgdL2NFTVoucher.redeemVoucherToL1(...)} was called
  /// @param marketData status of voucher when redeem call was initiated in L2
  function getRedeemClearanceKey(
    uint256 voucherId,
    address nft,
    uint256 tokenId,
    uint256 amount,
    address receiver,
    bytes32 blockHash,
    MgdL1MarketData calldata marketData,
    string memory tokenURI,
    bytes memory tokenIdMemoir
  )
    public
    pure
    returns (uint256)
  {
    return _generateL1ReleaseKey(
      voucherId, nft, tokenId, amount, receiver, blockHash, marketData, tokenURI, tokenIdMemoir
    );
  }

  /// @notice Releases NFT from escrow to owner.
  /// @param voucherId used while in L2
  /// @param nft contract address of NFT to release
  /// @param tokenId of NFT to release
  /// @param amount of editions of NFT to release
  /// @param receiver who will receive NFT
  /// @param blockHash when {MgdL2NFTVoucher.redeemVoucherToL1(...)} was called in L2
  /// @param marketData  latest status when {MgdL2NFTVoucher.redeemVoucherToL1(...)} was called in L2
  /// @param tokenURI ?required only when releasing a L2 natively created voucher
  /// @param memoir ?optional only when releasing a L2 natively created voucher (suggest to use the same as L2)
  /// @dev For L2 natively created vouchers, the `tokenId` must be `_REF_NUMBER` and a `tokenURI` must be passed.
  function releaseFromEscrow(
    uint256 voucherId,
    address nft,
    uint256 tokenId,
    uint256 amount,
    address receiver,
    bytes32 blockHash,
    MgdL1MarketData calldata marketData,
    string memory tokenURI,
    bytes memory memoir
  )
    external
  {
    uint256 key = getRedeemClearanceKey(
      voucherId, nft, tokenId, amount, receiver, blockHash, marketData, tokenURI, memoir
    );
    _releaseFromEscrow(key, voucherId, receiver, nft, tokenId, amount, marketData, tokenURI, memoir);
  }

  /// @notice Similar to `releaseFromEscrow` but with an authorized signature.
  function releaseFromEscrowWithSignature(
    uint256 voucherId,
    address nft,
    uint256 tokenId,
    uint256 amount,
    address receiver,
    bytes32 blockHash,
    MgdL1MarketData calldata marketData,
    string memory tokenURI,
    bytes memory memoir,
    uint256 deadline,
    bytes memory signature
  )
    external
  {
    uint256 key = getRedeemClearanceKey(
      voucherId, nft, tokenId, amount, receiver, blockHash, marketData, tokenURI, memoir
    );
    setRedeemClearanceKeyWithSignature(receiver, key, true, deadline, signature);
    _releaseFromEscrow(key, voucherId, receiver, nft, tokenId, amount, marketData, tokenURI, memoir);
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
    if (nft.ownerOf(tokenId) == address(this)) {
      MgdL1MarketData memory marketData = abi.decode(data, (MgdL1MarketData));

      (uint256 voucherId, bytes32 blockHash) =
        _generateL1EscrowedIdentifier(address(nft), tokenId, 1, from, marketData);

      _sendEscrowNoticeToL2(voucherId, true, TypeNFT.ERC721);

      emit EnterEscrow(address(nft), tokenId, 1, from, blockHash, marketData, voucherId);
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
    MgdL1MarketData memory marketData = abi.decode(data, (MgdL1MarketData));
    /**
     * TODO confirm if the below check is safe, given there could be
     * tokenIds of the same contract already in escrow.
     */
    if (nft.balanceOf(address(this), tokenId) >= amount) {
      (uint256 voucherId, bytes32 blockHash) =
        _generateL1EscrowedIdentifier(address(nft), tokenId, amount, from, marketData);

      _sendEscrowNoticeToL2(voucherId, true, TypeNFT.ERC1155);

      emit EnterEscrow(address(nft), tokenId, amount, from, blockHash, marketData, voucherId);
      return this.onERC1155Received.selector;
    } else {
      return _EMPTY_BYTES4;
    }
  }

  function onERC1155BatchReceived(
    address, // operator
    address, // operator
    uint256[] calldata, // ids
    uint256[] calldata, // values
    bytes calldata // data
  )
    external
    pure
    returns (bytes4)
  {
    revert MgdL2NFTEscrow__onERC1155BatchReceived_notSupported();
  }

  /// @notice Sets the contract address of {MgdL2NFTVoucher} deployed in L2.
  /// @param newVoucher address of {MgdL2NFTVoucher} deployed in L2.
  function setVoucherL2(address newVoucher, TypeNFT nftType) external {
    if (msg.sender != _mgdCompany.owner()) {
      revert MgdL2NFTEscrow__setVoucherL2_notAllowed();
    }
    _setVoucherL2(newVoucher, nftType);
  }

  /**
   * @dev Common flow to release NFT from escrow.
   */
  function _releaseFromEscrow(
    uint256 key,
    uint256 voucherId,
    address receiver,
    address nft,
    uint256 tokenId,
    uint256 amount,
    MgdL1MarketData calldata marketData,
    string memory tokenURI,
    bytes memory memoir
  )
    private
  {
    if (!redeemClearance[key]) {
      revert MgdL2NFTEscrow__releaseFromEscrow_notClearedOrAlreadyReleased();
    }
    _setRedeemClearance(key, false);
    burnedReleaseKey[key] = true;

    uint256 newTokenId;
    if (tokenId == _REF_NUMBER) {
      require(bytes(tokenURI).length > 0, "pass tokenURI");
      uint256 recordedId = recordedVoucherIdToTokenIds[voucherId];
      if (recordedId == 0) {
        newTokenId =
          IEscrowableNFT(nft).mintFromL2Native(receiver, amount, marketData, tokenURI, memoir);
        recordedVoucherIdToTokenIds[voucherId] = newTokenId;
      } else {
        IEscrowableNFT(nft).mintFromL2NativeRecorded(receiver, amount, recordedId, marketData);
        newTokenId = recordedId;
      }
    }
    if (newTokenId == 0) {
      IEscrowableNFT(nft).transfer(address(this), receiver, tokenId, amount);
      IEscrowableNFT(nft).updateMarketData(tokenId, marketData);
    }
    emit ReleasedEscrow(
      receiver, nft, tokenId == _REF_NUMBER ? newTokenId : tokenId, amount, voucherId, key
    );
  }

  /// @dev Returns signature v, r, s values.
  /// @param signature abi.encodePacked(r,s,v)
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

  function _generateL1EscrowedIdentifier(
    address nft,
    uint256 tokenId,
    uint256 amount,
    address owner,
    MgdL1MarketData memory marketData
  )
    private
    view
    returns (uint256 voucherId, bytes32 blockHash)
  {
    blockHash = blockhash(block.number - 1);
    voucherId = uint256(keccak256(abi.encode(nft, tokenId, amount, owner, blockHash, marketData)));
  }

  function _generateL1ReleaseKey(
    uint256 voucherId,
    address nft,
    uint256 tokenId,
    uint256 amount,
    address receiver,
    bytes32 blockHash,
    MgdL1MarketData calldata marketData,
    string memory tokenURI,
    bytes memory tokenIdMemoir
  )
    private
    pure
    returns (uint256 key)
  {
    if (tokenId == _REF_NUMBER) {
      bytes32 hashedUriMemoir = keccak256(abi.encode(tokenURI, tokenIdMemoir));
      key = uint256(
        keccak256(
          abi.encode(
            voucherId, nft, tokenId, amount, receiver, blockHash, marketData, hashedUriMemoir
          )
        )
      );
    } else {
      key = uint256(
        keccak256(abi.encode(voucherId, nft, tokenId, amount, receiver, blockHash, marketData))
      );
    }
  }

  function _sendEscrowNoticeToL2(uint256 voucherId, bool state, TypeNFT nftType) private {
    bytes memory message =
      abi.encodeWithSelector(MgdL2NFTVoucher.setL1NftMintClearance.selector, voucherId, state);
    address target = nftType == TypeNFT.ERC721 ? voucher721L2 : voucher1155L2;
    messenger.sendMessage(target, message, 1000000);
  }

  /// @dev Sets the canonical cross domain messenger address between L1<>L2 or L2<>L1
  /// @param newMessenger canonical address between L1 or L2
  function _setMessenger(address newMessenger) private {
    CommonCheckers.checkZeroAddress(newMessenger);
    messenger = ICrossDomainMessenger(newMessenger);
    emit SetMessenger(newMessenger);
  }

  /// @dev Sets the contract address of {MgdL2NFTVoucher} deployed in L2.
  function _setVoucherL2(address newVoucher, TypeNFT nftType) private {
    CommonCheckers.checkZeroAddress(newVoucher);
    if (nftType == TypeNFT.ERC721) {
      voucher721L2 = newVoucher;
    } else {
      voucher1155L2 = newVoucher;
    }
    emit SetVoucherL2(newVoucher, nftType);
  }

  /// @dev Revert if `data` is zero length
  function _checkDataNonZero(bytes memory data) private pure {
    if (data.length == 0) {
      revert("Wrong data size");
    }
  }

  function _setRedeemClearance(uint256 key, bool state) private {
    if (burnedReleaseKey[key]) {
      revert MgdL2NFTEscrow___setRedeemClearance_burnedReleaseKey();
    }
    redeemClearance[key] = state;
    emit RedeemClearanceKey(key, state);
  }

  function _checkDeadline(uint256 deadline) private view {
    require(block.timestamp <= deadline, "Expired deadline");
  }
}
