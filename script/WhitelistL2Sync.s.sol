// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import {MintGoldDustCompany} from "mgd-v2-contracts/MintGoldDustCompany.sol";
import {MGDCompanyL2Sync, CrossAction} from "../src/MGDCompanyL2Sync.sol";

contract WhitelistL2Sync is Script {
  /// PARAMS TO BE SET
  MGDCompanyL2Sync public constant MGDL2SYNC =
    MGDCompanyL2Sync(0x0000000000000000000000000000000000000000);
  uint256 public constant TARGET_CHAIN_ID = 0;
  address public constant ADDRESS_TO_WHITELIST = 0x0000000000000000000000000000000000000000;

  /**
   * @dev Run using shell command:
   * $forge script --rpc-url $<RPC_CHAIN> --private-key $<PRIVATE_KEY> \
   * --slow --verify --etherscan-api-key $<etherscan_key> --broadcast scripts/Whitelist.s.sol
   */
  function run() public {
    vm.startBroadcast();

    require(address(MGDL2SYNC) != address(0), "Set `MGDL2SYNC`");
    require(MGDL2SYNC.publicKey() != address(0), "Pubkey() in `MGDL2SYNC` undefined");
    require(
      address(MGDL2SYNC.crossDomainMessenger()) != address(0),
      "crossDomainMessenger() in `MGDL2SYNC` undefined"
    );
    require(TARGET_CHAIN_ID != 0, "Set `TARGET_CHAIN_ID`");
    require(
      MGDL2SYNC.crossDomainMGDCompany(TARGET_CHAIN_ID) != address(0),
      "CrossDomain address undefined"
    );
    require(ADDRESS_TO_WHITELIST != address(0), "Set `ADDRESS_TO_WHITELIST`");

    bytes32 digest = MGDL2SYNC.getDigestToSign(
      CrossAction.SetWhitelist,
      ADDRESS_TO_WHITELIST,
      true,
      TARGET_CHAIN_ID,
      block.timestamp + 1 days - 1 seconds
    );

    uint256 privKey = getPrivKey();
    require(privKey != 0, "Set `MGD_SIGNER` in `.env` file");
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(privKey, digest);

    bytes memory signature = abi.encodePacked(r, s, v);

    MGDL2SYNC.whitelistWithL2Sync(
      ADDRESS_TO_WHITELIST, true, TARGET_CHAIN_ID, block.timestamp + 1 days, signature
    );

    vm.stopBroadcast();
  }

  function getPrivKey() internal view returns (uint256 key) {
    bytes32 k = vm.envBytes32("PRIVATE_KEY");
    key = uint256(k);
  }
}
