// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {MintGoldDustCompany} from "mgd-v2-contracts/MintGoldDustCompany.sol";
import {CrossAction, MGDEIP712L2Sync, ECDSAUpgradeable} from "./MGDEIP712L2Sync.sol";
import {IL1crossDomainMessenger} from "./interfaces/IL1CrossDomainMessenger.sol";

/// @title MGDCompanyL2Sync
/// @notice An extension to {MintGoldDustCompany} containing functions that
/// syncs access levels management changes with a L2.
/// @author Mint Gold Dust LLC
/// @custom:contact klvh@mintgolddust.io
contract MGDCompanyL2Sync is MintGoldDustCompany, MGDEIP712L2Sync {
  /**
   * @dev Emit when `setCrossDomainMessenger()` is called.
   * @param messenger address to be set
   */
  event SetCrossDomainMessenger(address messenger);

  /**
   * @dev Emit when `setCrossDomainMGDCompany()` is called.
   * @param chainId of domain
   * @param mgdCompany address in the indicated domain
   */
  event SetCrossDomainMGDCompany(uint256 indexed chainId, address mgdCompany);

  /**
   * @dev Emit for soft failing functions.
   * @param deadline of the signature
   */
  event ExpiredDeadline(uint256 deadline);

  /**
   * @dev Emit when `receiveL1Sync()` fails.
   * @param action intended
   * @param account address
   * @param state change
   */
  event FailedReceiveL1Sync(CrossAction action, address account, bool state);

  /// Custom errors
  error MGDCompanyL2Sync__performL2Call_undefinedMGDCompanyAtChainId(uint256 chainId);

  IL1crossDomainMessenger public crossDomainMessenger;

  /// chain Id => MGDCompanyL2Sync address
  mapping(uint256 => address) public crossDomainMGDCompany;

  modifier onlyCrossMessenger() {
    require(msg.sender == address(crossDomainMessenger));
    _;
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /**
   * @notice Similar to `setValidator()` with L2 synchronizaton.
   * @param account to set as validator
   * @param state to be set
   * @param chainId where the syncing mgdCompany contract exists
   * @param deadline for the syncing to occur via this `signature`
   * @param mgdSignature generated from this `publicKey()`
   * @dev Requirements:
   * - `mgdSignature` should be generated by `MintGoldDustCompany.publicKey()`
   */
  function setValidatorWithL2Sync(
    address account,
    bool state,
    uint256 chainId,
    uint256 deadline,
    bytes calldata mgdSignature
  )
    external
    onlyOwner
    isZeroAddress(account)
  {
    _checkDeadline(deadline, true);

    bytes32 structHash =
      keccak256(abi.encode(_SETVALIDATOR_TYPEHASH, account, state, chainId, deadline));

    require(_verifySignature(publicKey, structHash, mgdSignature), "Invalid signature");

    _performL2Call(CrossAction.SetValidator, account, state, chainId, deadline, mgdSignature);
    _setValidator(account, state);
  }

  /**
   * @notice Similar to `whitelist()` with L2 synchronizaton.
   * @param account to set as validator
   * @param state to be set
   * @param chainId where the syncing mgdCompany contract exists
   * @param deadline for the syncing to occur via this `signature`
   * @param mgdSignature generated from this `publicKey()`
   * @dev Requirements:
   * - `mgdSignature` should be generated by `MintGoldDustCompany.publicKey()`
   */
  function whitelistWithL2Sync(
    address account,
    bool state,
    uint256 chainId,
    uint256 deadline,
    bytes calldata mgdSignature
  )
    external
    isValidatorOrOwner
    isZeroAddress(account)
  {
    _checkDeadline(deadline, true);

    bytes32 structHash =
      keccak256(abi.encode(_WHITELIST_TYPEHASH, account, state, chainId, deadline));

    require(_verifySignature(publicKey, structHash, mgdSignature), "Invalid signature");

    _performL2Call(CrossAction.SetWhitelist, account, state, chainId, deadline, mgdSignature);
    _whitelist(account, state);
  }

  function receiveL1Sync(bytes memory data) external onlyCrossMessenger {
    (CrossAction action, address account, bool state, uint256 deadline, bytes memory mgdSignature) =
      abi.decode(data, (CrossAction, address, bool, uint256, bytes));

    bool success;

    if (action == CrossAction.SetValidator) {
      bytes32 structHash =
        keccak256(abi.encode(_SETVALIDATOR_TYPEHASH, account, state, block.chainid, deadline));
      if (_verifySignature(publicKey, structHash, mgdSignature)) {
        _setValidator(account, state);
        success = true;
      }
    } else if (action == CrossAction.SetWhitelist) {
      bytes32 structHash =
        keccak256(abi.encode(_WHITELIST_TYPEHASH, account, state, block.chainid, deadline));
      if (_verifySignature(publicKey, structHash, mgdSignature)) {
        _whitelist(account, state);
        success = true;
      }
    }

    if (!success) {
      emit FailedReceiveL1Sync(action, account, state);
    }
  }

  /**
   * @notice Sets defined cross domain messenger address between
   * L1<>L2 or L2<>L1
   * @param messenger canonical address between L1 or L2
   */
  function setCrossDomainMessenger(address messenger) external onlyOwner isZeroAddress(messenger) {
    crossDomainMessenger = IL1crossDomainMessenger(messenger);
    emit SetCrossDomainMessenger(messenger);
  }

  /**
   * @notice Sets the mapping between a `chainId` and the {MGDCompany} contract
   * address there
   * @param chainId of the domain
   * @param mgdCompany address in the indicated domain
   */
  function setCrossDomainMGDCompany(
    uint256 chainId,
    address mgdCompany
  )
    external
    onlyOwner
    isZeroAddress(mgdCompany)
  {
    require(chainId != 0, "Invalid chainId");
    crossDomainMGDCompany[chainId] = mgdCompany;
    emit SetCrossDomainMGDCompany(chainId, mgdCompany);
  }

  function _performL2Call(
    CrossAction action,
    address account,
    bool state,
    uint256 chainId,
    uint256 deadline,
    bytes calldata mgdSignature
  )
    private
  {
    bytes memory message = abi.encodeWithSelector(
      this.receiveL1Sync.selector, abi.encode(action, account, state, deadline, mgdSignature)
    );
    if (crossDomainMGDCompany[chainId] == address(0)) {
      revert MGDCompanyL2Sync__performL2Call_undefinedMGDCompanyAtChainId(chainId);
    }
    crossDomainMessenger.sendMessage(crossDomainMGDCompany[chainId], message, 1000000);
  }

  function _checkDeadline(uint256 deadline, bool withRevert) private {
    if (withRevert) {
      require(block.timestamp < deadline, "Expired deadline");
    } else if (block.timestamp > deadline) {
      emit ExpiredDeadline(deadline);
    }
  }

  /**
   * @notice Verify a `signature` of a message was signed
   * by an `expectedSigner`.
   * @param expectedSigner is the signer address.
   * @param structHash is the _signature of the eip712 object generated off chain.
   * @param signature of the message
   */
  function _verifySignature(
    address expectedSigner,
    bytes32 structHash,
    bytes memory signature
  )
    private
    view
    returns (bool)
  {
    bytes32 digest = _hashTypedDataV4(structHash);
    address signer = ECDSAUpgradeable.recover(digest, signature);
    return signer == expectedSigner;
  }

  function _setValidator(address account, bool state) private {
    isAddressValidator[account] = state;
    emit ValidatorAdded(account, state);
  }

  function _whitelist(address account, bool state) private {
    isArtistApproved[account] = state;
    emit ArtistWhitelisted(account, state);
  }
}
