// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {console} from "forge-std/console.sol";
import {FileSystem} from "./utils/FileSystem.s.sol";
import {MgdScriptConstants} from "./MgdScriptConstants.s.sol";

import "./deploy/MgdDeployLibraries.s.sol";

enum Action {
    NOTHING,
    DEPLOY,
    UPGRADE,
    CONFIGURE
}

struct DeploymentConfiguration {
    Action company;
    Action memoir;
    Action escrow;
    Action mgd721;
    Action mgd1155;
    Action mgdVoucher721;
    Action mgdVoucher1155;
    Action mgdSetPrice;
    Action mgdAuction;
}

/**
 * @dev Run using shell command:
 * $forge script --rpc-url $<RPC_CHAIN> --private-key $<PRIVATE_KEY> \
 * --slow --verify --etherscan-api-key $<etherscan_key> --broadcast script/foundry/GlobalDeployerScript.s.sol
 */
contract GlobalDeployerScript is FileSystem, MgdScriptConstants {
    FileSystem fs;

    DeploymentConfiguration config =
        DeploymentConfiguration({
            company: Action.DEPLOY,
            memoir: Action.DEPLOY,
            escrow: Action.DEPLOY,
            mgd721: Action.DEPLOY,
            mgd1155: Action.DEPLOY,
            mgdVoucher721: Action.DEPLOY,
            mgdVoucher1155: Action.DEPLOY,
            mgdSetPrice: Action.DEPLOY,
            mgdAuction: Action.DEPLOY
        });

    function run() public {
        fs = new FileSystem();

        vm.startBroadcast();
        executeDeployActions(true);
        vm.stopBroadcast();
    }

    function executeDeployActions(bool withVouchers) internal {
        string memory chainName = fs.getChainName(block.chainid);

        // MgdCompanyL2Sync
        if (config.company == Action.DEPLOY) {
            MgdCompanyL2SyncParams memory params = MgdCompanyL2SyncParams({
                owner: msg.sender,
                primarySaleFeePercent: _PRIMARY_SALE_FEE_PERCENT,
                secondarySaleFeePercent: _SECONDARY_SALE_FEE_PERCENT,
                collectorFee: _COLLECTOR_FEE,
                maxRoyalty: _MAX_ROYALTY,
                auctionDurationInMinutes: _AUCTION_DURATION,
                auctionFinalMinute: _AUCTION_EXTENSION
            });
            MgdCompanyL2SyncDeployer.deployMgdCompanyL2Sync(fs, params, false);
        }
        // MintGoldDustMemoir
        if (config.memoir == Action.DEPLOY) {
            MintGoldDustMemoirDeployer.deployMintGoldDustMemoir(fs, false);
        }
        // MgdL2NFTEscrow
        if (config.escrow == Action.DEPLOY) {
            MgdL2NFTEscrowParams memory params = MgdL2NFTEscrowParams({
                mgdCompanyL2Sync: getSafeAddress("MgdCompanyL2Sync", chainName)
            });
            MgdL2NFTEscrowDeployer.deployMgdL2NFTEscrow(fs, params, false);
        }
        // MgdERC721PermitEscrowable
        if (config.mgd721 == Action.DEPLOY && !withVouchers) {
            MgdERC721PermitEscrowableParams
                memory params = MgdERC721PermitEscrowableParams({
                    mgdCompanyL2Sync: getSafeAddress(
                        "MgdCompanyL2Sync",
                        chainName
                    )
                });
            MgdERC721PermitEscrowableDeployer.deployMgdERC721PermitEscrowable(
                fs,
                params,
                false
            );
        }
        // MgdERC1155PermitEscrowable
        if (config.mgd1155 == Action.DEPLOY && !withVouchers) {
            MgdERC1155PermitEscrowableParams
                memory params = MgdERC1155PermitEscrowableParams({
                    mgdCompanyL2Sync: getSafeAddress(
                        "MgdCompanyL2Sync",
                        chainName
                    )
                });
            MgdERC1155PermitEscrowableDeployer.deployMgdERC1155PermitEscrowable(
                    fs,
                    params,
                    false
                );
        }
        // Mgd721L2Voucher
        if (config.mgdVoucher721 == Action.DEPLOY && withVouchers) {
            string memory pairChain = fs.getPairChain(block.chainid);
            Mgd721L2VoucherParams memory params = Mgd721L2VoucherParams({
                mgdCompanyL2Sync: getSafeAddress("MgdCompanyL2Sync", chainName),
                mgdL2NFTescrow: getSafeAddress("MgdL2NFTEscrow", pairChain),
                mgdERC721: getSafeAddress(
                    "MgdERC721PermitEscrowable",
                    pairChain
                ),
                crossDomainMessenger: getSafeAddress("Messenger", chainName)
            });
            Mgd721L2VoucherDeployer.deployMgd721L2Voucher(fs, params, false);
        }
        // Mgd1155L2Voucher
        if (config.mgdVoucher1155 == Action.DEPLOY && withVouchers) {
            string memory pairChain = fs.getPairChain(block.chainid);
            Mgd1155L2VoucherParams memory params = Mgd1155L2VoucherParams({
                mgdCompanyL2Sync: getSafeAddress("MgdCompanyL2Sync", chainName),
                mgdL2NFTescrow: getSafeAddress("MgdL2NFTEscrow", pairChain),
                mgdERC1155: getSafeAddress(
                    "MgdERC1155PermitEscrowable",
                    pairChain
                ),
                crossDomainMessenger: getSafeAddress("Messenger", chainName)
            });
            Mgd1155L2VoucherDeployer.deployMgd1155L2Voucher(fs, params, false);
        }
        // MintGoldDustSetPrice
        if (config.mgdSetPrice == Action.DEPLOY) {
            MintGoldDustSetPriceParams memory params;
            params.mintGoldDustCompany = getSafeAddress(
                "MgdCompanyL2Sync",
                chainName
            );
            params.mintGoldDustERC721Address = payable(
                getSafeAddress(
                    withVouchers
                        ? "Mgd721L2Voucher"
                        : "MgdERC721PermitEscrowable",
                    chainName
                )
            );
            params.mintGoldDustERC1155Address = payable(
                getSafeAddress(
                    withVouchers
                        ? "Mgd1155L2Voucher"
                        : "MgdERC1155PermitEscrowable",
                    chainName
                )
            );
            MintGoldDustSetPriceDeployer.deployMintGoldDustSetPrice(
                fs,
                params,
                false
            );
        }
        // MintGoldDustMarketplaceAuction
        if (config.mgdAuction == Action.DEPLOY) {
            MintGoldDustMarketplaceAuctionParams memory params;
            params.mintGoldDustCompany = getSafeAddress(
                "MgdCompanyL2Sync",
                chainName
            );
            params.mintGoldDustERC721Address = payable(
                getSafeAddress(
                    withVouchers
                        ? "Mgd721L2Voucher"
                        : "MgdERC721PermitEscrowable",
                    chainName
                )
            );
            params.mintGoldDustERC1155Address = payable(
                getSafeAddress(
                    withVouchers
                        ? "Mgd1155L2Voucher"
                        : "MgdERC1155PermitEscrowable",
                    chainName
                )
            );
            MintGoldDustMarketplaceAuctionDeployer
                .deployMintGoldDustMarketplaceAuction(fs, params, false);
        }
    }

    function getSafeAddress(
        string memory contractLabel,
        string memory chainName
    ) private view returns (address) {
        try fs.getAddress(contractLabel, chainName) returns (address addr) {
            return addr;
        } catch {
            revert FileNotFound(chainName, contractLabel);
        }
    }
}
