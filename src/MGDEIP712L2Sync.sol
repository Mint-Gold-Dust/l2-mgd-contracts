// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {ECDSAUpgradeable} from
  "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";

enum CrossAction {
  SetValidator,
  SetWhitelist
}

contract MGDEIP712L2Sync {
  /// errors
  error MGDEIP712L2Sync_getDigestToSign_unknownCrossAction();

  bytes32 private constant _TYPE_HASH =
    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

  bytes32 internal constant _SETVALIDATOR_TYPEHASH =
    keccak256("SetValidator(address account,bool state,uint256 chainId,uint256 deadline)");

  bytes32 internal constant _WHITELIST_TYPEHASH =
    keccak256("Whitelist(address account,bool state,uint256 chainId,uint256 deadline)");

  string public constant NAME = "MGDL2SyncEIP712";
  string public constant VERSION = "v0.0.1";

  uint256 private constant _MAINNET_CHAINID = 0x1;
  address private constant _MGD_COMPANY_ADDRESS = 0x2f00435f003d6568933586b4A272c6c6B481e0aD;

  bytes32 private _cachedHashedName;
  bytes32 private _cachedHashedVersion;

  function getDigestToSign(
    CrossAction action,
    address account,
    bool state,
    uint256 chainId,
    uint256 deadline
  )
    public
    view
    returns (bytes32 digest)
  {
    if (action == CrossAction.SetValidator) {
      bytes32 structHash =
        keccak256(abi.encode(_SETVALIDATOR_TYPEHASH, account, state, chainId, deadline));
      digest = _hashTypedDataV4(structHash);
    } else if (action == CrossAction.SetWhitelist) {
      bytes32 structHash =
        keccak256(abi.encode(_WHITELIST_TYPEHASH, account, state, chainId, deadline));
      digest = _hashTypedDataV4(structHash);
    } else {
      revert MGDEIP712L2Sync_getDigestToSign_unknownCrossAction();
    }
  }

  /**
   * @dev Initializes the domain separator and parameter caches.
   */
  function __EIP712_init() internal {
    _cachedHashedName = keccak256(bytes(NAME));
    _cachedHashedVersion = keccak256(bytes(VERSION));
  }

  function _EIP712NameHash() internal view returns (bytes32) {
    return _cachedHashedName;
  }

  function _EIP712VersionHash() internal view returns (bytes32) {
    return _cachedHashedVersion;
  }

  /**
   * @dev Returns the domain separator for mainnet ONLY signed messages for the {MintGoldDustCompany}
   * contract address that relays admin changes to any L2.
   *
   */
  function _domainSeparatorV4() internal view returns (bytes32) {
    return keccak256(
      abi.encode(
        _TYPE_HASH, _EIP712NameHash(), _EIP712VersionHash(), _MAINNET_CHAINID, _MGD_COMPANY_ADDRESS
      )
    );
  }

  function _hashTypedDataV4(bytes32 structHash) internal view virtual returns (bytes32) {
    return ECDSAUpgradeable.toTypedDataHash(_domainSeparatorV4(), structHash);
  }
}
