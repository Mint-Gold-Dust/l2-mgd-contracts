// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

contract MockCrossDomainMessenger {
  /**
   * @notice Emitted whenever a message is sent to the other chain.
   *
   * @param target       Address of the recipient of the message.
   * @param sender       Address of the sender of the message.
   * @param message      Message to trigger the recipient address with.
   * @param messageNonce Unique nonce attached to the message.
   * @param gasLimit     Minimum gas limit that the message can be executed with.
   */
  event SentMessage(
    address indexed target, address sender, bytes message, uint256 messageNonce, uint256 gasLimit
  );

  /**
   * @notice Additional event data to emit, required as of Bedrock. Cannot be merged with the
   *         SentMessage event without breaking the ABI of this contract, this is good enough.
   *
   * @param sender Address of the sender of the message.
   * @param value  ETH value sent along with the message to the recipient.
   */
  event SentMessageExtension1(address indexed sender, uint256 value);
  /**
   * @notice Emitted whenever a message is successfully relayed on this chain.
   *
   * @param msgHash Hash of the message that was relayed.
   */
  event RelayedMessage(bytes32 indexed msgHash);

  /**
   * @notice Emitted whenever a message fails to be relayed on this chain.
   *
   * @param msgHash Hash of the message that failed to be relayed.
   */
  event FailedRelayedMessage(bytes32 indexed msgHash);

  /**
   * @notice Current message version identifier.
   */
  uint16 public constant MESSAGE_VERSION = 1;

  /**
   * @notice Gas reserved for finalizing the execution of `relayMessage` after the safe call.
   */
  uint64 public constant RELAY_RESERVED_GAS = 40_000;

  /**
   * @notice Nonce for the next message to be sent, without the message version applied. Use the
   *         messageNonce getter which will insert the message version into the nonce to give you
   *         the actual nonce to be used for the message.
   */
  uint240 internal msgNonce;

  /**
   * @notice Sends a message to some target address on the other chain. Note that if the call
   *         always reverts, then the message will be unrelayable, and any ETH sent will be
   *         permanently locked. The same will occur if the target on the other chain is
   *         considered unsafe (see the _isUnsafeTarget() function).
   *
   * @param _target      Target contract or wallet address.
   * @param _message     Message to trigger the target address with.
   * @param _minGasLimit Minimum gas limit that the message can be executed with.
   */
  function sendMessage(
    address _target,
    bytes calldata _message,
    uint32 _minGasLimit
  )
    external
    payable
  {
    /**
     * Actions omitted to simplify mocking.
     */
    emit SentMessage(_target, msg.sender, _message, messageNonce(), _minGasLimit);
    emit SentMessageExtension1(msg.sender, msg.value);

    unchecked {
      ++msgNonce;
    }
  }

  /**
   * @notice Relays a message that was sent by the other CrossDomainMessenger contract. Can only
   *         be executed via cross-chain call from the other messenger OR if the message was
   *         already received once and is currently being replayed.
   *
   * @param _nonce       Nonce of the message being relayed.
   * @param _sender      Address of the user who sent the message.
   * @param _target      Address that the message is targeted at.
   * @param _value       ETH value to send with the message.
   * @param _minGasLimit Minimum amount of gas that the message can be executed with.
   * @param _message     Message to send to the target.
   */
  function relayMessage(
    uint256 _nonce,
    address _sender,
    address _target,
    uint256 _value,
    uint256 _minGasLimit,
    bytes calldata _message
  )
    external
    payable
  {
    /**
     * Actions omitted to simplify mocking.
     */
    bytes32 versionedHash =
      hashCrossDomainMessageV1(_nonce, _sender, _target, _value, _minGasLimit, _message);

    bool success = call(_target, gasleft() - RELAY_RESERVED_GAS, _value, _message);

    if (success) {
      emit RelayedMessage(versionedHash);
    } else {
      emit FailedRelayedMessage(versionedHash);
    }
  }

  /**
   * @notice Retrieves the next message nonce. Message version will be added to the upper two
   *         bytes of the message nonce. Message version allows us to treat messages as having
   *         different structures.
   *
   * @return Nonce of the next message to be sent, with added message version.
   */
  function messageNonce() public view returns (uint256) {
    return _encodeVersionedNonce(msgNonce, MESSAGE_VERSION);
  }

  /**
   * @notice Adds a version number into the first two bytes of a message nonce.
   *
   * @param _nonce   Message nonce to encode into.
   * @param _version Version number to encode into the message nonce.
   *
   * @return Message nonce with version encoded into the first two bytes.
   */
  function _encodeVersionedNonce(uint240 _nonce, uint16 _version) internal pure returns (uint256) {
    uint256 nonce;
    assembly {
      nonce := or(shl(240, _version), _nonce)
    }
    return nonce;
  }

  /**
   * @notice Hashes a cross domain message based on the V1 (current) encoding.
   *
   * @param _nonce    Message nonce.
   * @param _sender   Address of the sender of the message.
   * @param _target   Address of the target of the message.
   * @param _value    ETH value to send to the target.
   * @param _gasLimit Gas limit to use for the message.
   * @param _data     Data to send with the message.
   *
   * @return Hashed cross domain message.
   */
  function hashCrossDomainMessageV1(
    uint256 _nonce,
    address _sender,
    address _target,
    uint256 _value,
    uint256 _gasLimit,
    bytes memory _data
  )
    internal
    pure
    returns (bytes32)
  {
    return keccak256(
      abi.encodeWithSignature(
        "relayMessage(uint256,address,address,uint256,uint256,bytes)",
        _nonce,
        _sender,
        _target,
        _value,
        _gasLimit,
        _data
      )
    );
  }

  /**
   * @notice Perform a low level call without copying any returndata
   *
   * @param _target   Address to call
   * @param _gas      Amount of gas to pass to the call
   * @param _value    Amount of value to pass to the call
   * @param _calldata Calldata to pass to the call
   */
  function call(
    address _target,
    uint256 _gas,
    uint256 _value,
    bytes memory _calldata
  )
    internal
    returns (bool)
  {
    bool _success;
    assembly {
      _success :=
        call(
          _gas, // gas
          _target, // recipient
          _value, // ether value
          add(_calldata, 32), // inloc
          mload(_calldata), // inlen
          0, // outloc
          0 // outlen
        )
    }
    return _success;
  }
}
