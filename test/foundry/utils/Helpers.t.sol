// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {Test} from "forge-std/Test.sol";
import {MgdL1MarketData} from "../../../src/MgdL2NFTEscrow.sol";

contract Helpers is Test {
  function generate_packedSignature(
    bytes32 digest,
    uint256 signerPrivKey
  )
    internal
    pure
    returns (bytes memory signature)
  {
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivKey, digest);
    return abi.encodePacked(r, s, v);
  }

  function generate_valuesSignature(
    bytes32 digest,
    uint256 signerPrivKey
  )
    internal
    pure
    returns (uint8 v, bytes32 r, bytes32 s)
  {
    (v, r, s) = vm.sign(signerPrivKey, digest);
  }

  function generate_L1EscrowedIdentifier(
    address nft,
    uint256 tokenId,
    uint256 amount,
    address owner,
    MgdL1MarketData memory marketData
  )
    internal
    view
    returns (uint256 voucherId, bytes32 blockHash)
  {
    blockHash = blockhash(block.number);
    voucherId = uint256(keccak256(abi.encode(nft, tokenId, amount, owner, blockHash, marketData)));
  }

  function structure_tokenIdData(bytes memory tokenIdData)
    internal
    pure
    returns (MgdL1MarketData memory marketData)
  {
    (
      marketData.artist,
      marketData.hasCollabs,
      marketData.tokenWasSold,
      marketData.collabsQuantity,
      marketData.primarySaleQuantityToSell,
      marketData.royaltyPercent,
      marketData.collabs,
      marketData.collabsPercentage
    ) = abi.decode(
      tokenIdData, (address, bool, bool, uint40, uint40, uint256, address[4], uint256[5])
    );
  }
}
