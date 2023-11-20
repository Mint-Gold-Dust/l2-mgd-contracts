// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {MintGoldDustCompany} from "mgd-v2-contracts/MintGoldDustCompany.sol";

/// @title MGDCompanyL2Sync
/// @notice An extension to {MintGoldDustCompany} containing functions that
///         syncs access levels management changes with a L2.
/// @author Mint Gold Dust LLC
/// @custom:contact klvh@mintgolddust.io
contract MGDCompanyL2Sync is MintGoldDustCompany {
  function setValidatorWithL2Sync(
    address _address,
    bool _state,
    uint8 v,
    bytes32 r,
    bytes32 s
  )
    external
    onlyOwner
    isZeroAddress(_address)
  {
    isAddressValidator[_address] = _state;
    emit ValidatorAdded(_address, _state);
  }
}
