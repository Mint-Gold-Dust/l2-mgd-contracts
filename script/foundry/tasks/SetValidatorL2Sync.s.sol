// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import {MintGoldDustCompany} from "mgd-v2-contracts/marketplace/MintGoldDustCompany.sol";
import {MgdCompanyL2Sync, CrossAction} from "../../../src/MgdCompanyL2Sync.sol";

contract SetValidatorL2Sync is Script {
    /// PARAMS TO BE SET
    MgdCompanyL2Sync public constant MGDL2SYNC =
        MgdCompanyL2Sync(0x9ec99f79510fe675c22e537B505c4B3D0e487Dbe);
    uint256 public constant TARGET_CHAIN_ID = 84532;
    address public constant ADDRESS_TO_SET_VALIDATOR =
        0x4c56Bb56b27cc3Bb46FA5925dcF34Bf068C4558E;
    bool public constant NEW_STATE = false;
    uint256 public constant DEADLINE = 1701417600;

    /**
     * @dev Run using shell command:
     * $forge script --rpc-url $<RPC_CHAIN> --private-key $<PRIVATE_KEY> \
     * --slow --broadcast script/foundry/SetValidatorL2Sync.s.sol
     */
    function run() public {
        vm.startBroadcast();

        require(address(MGDL2SYNC) != address(0), "Set `MGDL2SYNC`");
        require(
            MGDL2SYNC.publicKey() != address(0),
            "Pubkey() in `MGDL2SYNC` undefined"
        );
        require(
            address(MGDL2SYNC.messenger()) != address(0),
            "crossDomainMessenger() in `MGDL2SYNC` undefined"
        );
        require(TARGET_CHAIN_ID != 0, "Set `TARGET_CHAIN_ID`");
        require(
            MGDL2SYNC.crossDomainMGDCompany(TARGET_CHAIN_ID) != address(0),
            "CrossDomain address undefined"
        );
        require(
            ADDRESS_TO_SET_VALIDATOR != address(0),
            "Set `ADDRESS_TO_SET_VALIDATOR`"
        );
        require(DEADLINE != 0, "Set `DEADLINE`");

        bytes32 digest = MGDL2SYNC.getDigestToSign(
            CrossAction.SetValidator,
            ADDRESS_TO_SET_VALIDATOR,
            NEW_STATE,
            TARGET_CHAIN_ID,
            DEADLINE
        );
        console.log("Digest:");
        console.logBytes32(digest);

        uint256 privKey = getPrivKey();
        require(privKey != 0, "Set `MGD_SIGNER_KEY` in `.env` file");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privKey, digest);

        bytes memory signature = abi.encodePacked(r, s, v);
        console.log("signature:");
        console.logBytes(signature);

        MGDL2SYNC.setValidatorWithL2Sync(
            ADDRESS_TO_SET_VALIDATOR,
            NEW_STATE,
            TARGET_CHAIN_ID,
            DEADLINE,
            signature
        );

        vm.stopBroadcast();
    }

    function getPrivKey() internal view returns (uint256 key) {
        bytes32 k = vm.envBytes32("MGD_SIGNER_KEY");
        key = uint256(k);
    }
}
