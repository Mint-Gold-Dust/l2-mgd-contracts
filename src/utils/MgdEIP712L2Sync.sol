// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {ECDSAUpgradeable} from
  "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";

enum CrossAction {
  SetValidator,
  SetWhitelist
}

/// @title MgdEIP712L2Sync
/// @notice EIP721 version for MGDCompanyL2Sync
/// @author Mint Gold Dust LLC
/// @custom:contact klvh@mintgolddust.io
abstract contract MgdEIP712L2Sync {
  /// Events
  /**
   * @dev Emit when `setCrossDomainMGDCompany()` is called.
   * @param chainId of cross domain
   * @param mgdCompany address in the indicated domain
   */
  event SetCrossDomainMGDCompany(uint256 chainId, address mgdCompany);

  /// Errors
  error MgdEIP712L2Sync_getDigestToSign_unknownCrossAction();

  /// Constants
  string public constant NAME = "MGDL2SyncEIP712";
  string public constant VERSION = "v0.0.1";

  bytes32 internal constant _TYPE_HASH =
    keccak256("MgdEIP712L2SyncDomain(string name,string version,address verifyingContract)");
  bytes32 internal constant _SETVALIDATOR_TYPEHASH =
    keccak256("SetValidator(address account,bool state,uint256 chainId,uint256 deadline)");
  bytes32 internal constant _WHITELIST_TYPEHASH =
    keccak256("Whitelist(address account,bool state,uint256 chainId,uint256 deadline)");
  uint256 internal constant _MAINNET_CHAINID = 0x1;

  /// Storage

  ///@dev keccak256(abi.encodePacked("MgdEIP712L2Sync_Storage"))
  bytes32 private constant MgdEIP712L2SyncStorageLocation =
    0x61aced8c5770c0c87dc43720e6727c6d7e783173d88587bda0edf1a603612573;

  struct MgdEIP712L2Sync_Storage {
    uint256 _crossChainId;
    address _crossDomainMGDCompany; // Add more storage after here
  }

  function _getMgdEIP712L2SyncStorage() internal pure returns (MgdEIP712L2Sync_Storage storage $) {
    assembly {
      $.slot := MgdEIP712L2SyncStorageLocation
    }
  }

  /// Methods
  function setCrossDomainMGDCompany(uint256 chainId, address mgdCompany) external virtual;

  /**
   * @notice Helper function to get the digest to sign
   * @dev Requirements:
   * - Should not be used within contract
   */
  function getDigestToSign(
    CrossAction action,
    address account,
    bool state,
    uint256 chainId,
    uint256 deadline
  )
    external
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
      revert MgdEIP712L2Sync_getDigestToSign_unknownCrossAction();
    }
  }

  function crossDomainMGDCompany() public view returns (address) {
    MgdEIP712L2Sync_Storage storage $ = _getMgdEIP712L2SyncStorage();
    return $._crossDomainMGDCompany;
  }

  /**
   * @notice Sets the cross domain MGDCompany address
   * @param chainId of domain
   * @param mgdCompany address of the L2 or L1 MGDCompany opposite to this.domain
   */
  function _setCrossDomainMGDCompany(uint256 chainId, address mgdCompany) internal {
    MgdEIP712L2Sync_Storage storage $ = _getMgdEIP712L2SyncStorage();
    $._crossDomainMGDCompany = mgdCompany;
    $._crossChainId = chainId;
    emit SetCrossDomainMGDCompany(chainId, mgdCompany);
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
    internal
    view
    returns (bool)
  {
    bytes32 digest = _hashTypedDataV4(structHash);
    address signer = ECDSAUpgradeable.recover(digest, signature);
    return signer == expectedSigner;
  }

  function _hashTypedDataV4(bytes32 structHash) internal view virtual returns (bytes32) {
    return ECDSAUpgradeable.toTypedDataHash(_domainSeparator(), structHash);
  }

  function _getCrossDomain() internal view returns (uint256) {
    MgdEIP712L2Sync_Storage storage $ = _getMgdEIP712L2SyncStorage();
    return block.chainid == _MAINNET_CHAINID ? $._crossChainId : block.chainid;
  }

  function _EIP712NameHash() private pure returns (bytes32) {
    return keccak256(bytes(NAME));
  }

  function _EIP712VersionHash() private pure returns (bytes32) {
    return keccak256(bytes(VERSION));
  }

  function _domainSeparator() private view returns (bytes32) {
    return keccak256(
      abi.encode(_TYPE_HASH, _EIP712NameHash(), _EIP712VersionHash(), _getAuthorizedAddress())
    );
  }

  function _getAuthorizedAddress() private view returns (address) {
    return block.chainid == _MAINNET_CHAINID ? crossDomainMGDCompany() : address(this);
  }
}
