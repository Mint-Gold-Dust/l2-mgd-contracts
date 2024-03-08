// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {ECDSAUpgradeable} from
  "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";

contract MgdEIP712Esrcrow {
  /// Constants
  string public constant NAME = "MgdEIP712Esrcrow";
  string public constant VERSION = "v0.0.1";

  bytes32 internal constant _TYPE_HASH = keccak256(
    "MgdEIP712Esrcrow(string name,string version,uint256 chainid,address verifyingContract)"
  );
  bytes32 internal constant _SETCLEARANCE_TYPEHASH = keccak256(
    "SetRedeemClearanceKey(address receiver,uint256 key,bool state,uint256 nonce,uint256 deadline)"
  );

  /// Storage

  ///@dev keccak256(abi.encodePacked("MgdEIP712Esrcrow_Storage"))
  bytes32 private constant MgdEIP712EsrcrowStorageLocation =
    0xc0bf8c2904a48943520a982c214d6d82eca4a22f5498921f993cd4575b5a8f20;

  struct MMgdEIP712Esrcrow_Storage {
    mapping(address => uint256) _currentNonce;
  }

  function _getMgdEIP712EsrcrowStorage()
    internal
    pure
    returns (MMgdEIP712Esrcrow_Storage storage $)
  {
    assembly {
      $.slot := MgdEIP712EsrcrowStorageLocation
    }
  }

  /**
   * @notice Helper function to get the digest to sign
   * @dev Requirements:
   * - Should not be used within contract
   */
  function getDigestToSign(
    address receiver,
    uint256 key,
    bool state,
    uint256 deadline
  )
    external
    view
    returns (bytes32 digest)
  {
    bytes32 structHash = keccak256(
      abi.encode(_SETCLEARANCE_TYPEHASH, receiver, key, state, getCurrentNonce(receiver), deadline)
    );
    digest = _hashTypedDataV4(structHash);
  }

  /**
   * @notice Returns the current nonce for a `receiver`.
   */
  function getCurrentNonce(address receiver) public view returns (uint256) {
    return _getMgdEIP712EsrcrowStorage()._currentNonce[receiver];
  }

  /**
   * @dev Returns the current nonce for a `receiver` and increments it.
   */
  function _useNonce(address receiver) internal returns (uint256 current) {
    MMgdEIP712Esrcrow_Storage storage $ = _getMgdEIP712EsrcrowStorage();
    current = $._currentNonce[receiver];
    $._currentNonce[receiver] += 1;
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

  function _EIP712NameHash() private pure returns (bytes32) {
    return keccak256(bytes(NAME));
  }

  function _EIP712VersionHash() private pure returns (bytes32) {
    return keccak256(bytes(VERSION));
  }

  function _domainSeparator() private view returns (bytes32) {
    return keccak256(
      abi.encode(_TYPE_HASH, _EIP712NameHash(), _EIP712VersionHash(), block.chainid, address(this))
    );
  }
}
