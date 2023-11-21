// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {MintGoldDustCompany} from "mgd-v2-contracts/MintGoldDustCompany.sol";
import {MGDL2SyncEIP712, ECDSAUpgradeable} from "./MGDL2SyncEIP712.sol";
import {SafeAccountChecker, ISafe} from "./utils/SafeAccountChecker.sol";

/// @title MGDCompanyL2Sync
/// @notice An extension to {MintGoldDustCompany} containing functions that
///         syncs access levels management changes with a L2.
/// @author Mint Gold Dust LLC
/// @custom:contact klvh@mintgolddust.io
contract MGDCompanyL2Sync is MGDL2SyncEIP712, SafeAccountChecker, MintGoldDustCompany {
  /// Custom errors
  error MGDCompanyL2Sync_setValidatorWithL2Sync_longDeadline();
  error MGDCompanyL2Sync_setValidatorWithL2Sync_notValidSigner();

  bytes32 private constant _SETVALIDATOR_TYPEHASH =
    keccak256("SetValidator(address account,bool state,uint256 deadline)");

  function setValidatorWithL2Sync(
    address account,
    bool state,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  )
    external
    onlyOwner
    isZeroAddress(account)
  {
    if (deadline > block.timestamp + 1 days) {
      revert MGDCompanyL2Sync_setValidatorWithL2Sync_longDeadline();
    }

    bytes32 structHash = keccak256(abi.encode(_SETVALIDATOR_TYPEHASH, account, state, deadline));
    bytes32 digest = _hashTypedDataV4(structHash);
    address signer = ECDSAUpgradeable.recover(digest, v, r, s);

    if (_isOwnerAContract() && isAddressASafe(owner())) {
      if (!isAccountOwnerInSafe(signer, owner())) {
        revert MGDCompanyL2Sync_setValidatorWithL2Sync_notValidSigner();
      }
    } else {}

    if (block.chainid == 0x1) {
      isAddressValidator[account] = state;
    }

    emit ValidatorAdded(account, state);
  }

  function _isOwnerAContract() internal view returns (bool) {
    return address(owner()).code.length > 0;
  }
}
