// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import {MintGoldDustCompany} from "mgd-v2-contracts/MintGoldDustCompany.sol";
import {MGDCompanyL2Sync, CrossAction} from "../../src/MGDCompanyL2Sync.sol";

contract WhitelistL2Sync is Script {
  /// PARAMS TO BE SET
  MGDCompanyL2Sync public constant MGDL2SYNC =
    MGDCompanyL2Sync(0x9ec99f79510fe675c22e537B505c4B3D0e487Dbe);
  uint256 public constant TARGET_CHAIN_ID = 84532;
  address public constant ADDRESS_TO_WHITELIST = 0x7598940ffE4db0De85cfC2296964c84090854fbe;
  bool public constant NEW_STATE = false;
  uint256 public constant DEADLINE = 1701417600;

  /**
   * @dev Run using shell command:
   * $forge script --rpc-url $<RPC_CHAIN> --private-key $<PRIVATE_KEY> \
   * --slow --verify --etherscan-api-key $<etherscan_key> --broadcast scripts/WhitelistL2Sync.s.sol
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
    require(DEADLINE != 0, "Set `DEADLINE`");

    bytes32 digest = MGDL2SYNC.getDigestToSign(
      CrossAction.SetWhitelist, ADDRESS_TO_WHITELIST, NEW_STATE, TARGET_CHAIN_ID, DEADLINE
    );
    console.log("Digest:");
    console.logBytes32(digest);

    uint256 privKey = getPrivKey();
    require(privKey != 0, "Set `MGD_SIGNER_KEY` in `.env` file");
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(privKey, digest);

    bytes memory signature = abi.encodePacked(r, s, v);
    console.log("signature:");
    console.logBytes(signature);

    MGDL2SYNC.whitelistWithL2Sync(
      ADDRESS_TO_WHITELIST, NEW_STATE, TARGET_CHAIN_ID, DEADLINE, signature
    );

    vm.stopBroadcast();
  }

  function getPrivKey() internal view returns (uint256 key) {
    bytes32 k = vm.envBytes32("MGD_SIGNER_KEY");
    key = uint256(k);
  }
}
