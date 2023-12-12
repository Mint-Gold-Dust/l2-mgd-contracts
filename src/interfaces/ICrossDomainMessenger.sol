// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

interface ICrossDomainMessenger {
  /// https://github.com/ethereum-optimism/optimism/blob/develop/packages/contracts-bedrock/src/L1/L1CrossDomainMessenger.sol
  function sendMessage(address _target, bytes memory _message, uint32 _gasLimit) external;
}
