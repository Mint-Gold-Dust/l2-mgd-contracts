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
   * @notice Current message version identifier.
   */
  uint16 public constant MESSAGE_VERSION = 1;

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
}
