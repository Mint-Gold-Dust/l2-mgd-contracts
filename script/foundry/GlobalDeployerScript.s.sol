// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {console} from "forge-std/console.sol";
import {FileSystem} from "./utils/FileSystem.s.sol";
import {MgdScriptConstants} from "./MgdScriptConstants.s.sol";
import {TypeNFT} from "../../src/voucher/VoucherDataTypes.sol";

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
        executeDeployActions(false);
        vm.stopBroadcast();
    }

    function executeDeployActions(bool withVouchers) internal {
        string memory chainName = fs.getChainName(block.chainid);
        string memory pairChain = fs.getPairChainName(block.chainid);

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
            MgdCompanyL2Sync company = MgdCompanyL2SyncDeployer
                .deployMgdCompanyL2Sync(fs, params, false);
            company.setMessenger(getSafeAddress("Messenger", chainName));
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
                    ),
                    baseURI: _BASE_URI
                });
            MgdERC1155PermitEscrowableDeployer.deployMgdERC1155PermitEscrowable(
                    fs,
                    params,
                    false
                );
        }
        // Mgd721L2Voucher
        if (config.mgdVoucher721 == Action.DEPLOY && withVouchers) {
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

    function executeConfigureActions() internal {
        string memory chainName = fs.getChainName(block.chainid);
        string memory pairChain = fs.getPairChainName(block.chainid);

        // MgdCompanyL2Sync
        if (config.company == Action.CONFIGURE) {
            MgdCompanyL2Sync company = MgdCompanyL2Sync(
                getSafeAddress("MgdCompanyL2Sync", chainName)
            );
            if (address(company.messenger()) == address(0)) {
                company.setMessenger(getSafeAddress("Messenger", chainName));
            }
            company.setCrossDomainMGDCompany(
                getPairChainId(block.chainid),
                getSafeAddress("MgdCompanyL2Sync", pairChain)
            );
            company.setPublicKey(_MGD_SIGNER);
        }
        // MgdL2NFTEscrow
        if (config.escrow == Action.CONFIGURE) {
            MgdL2NFTEscrow escrow = MgdL2NFTEscrow(
                getSafeAddress("MgdL2NFTEscrow", chainName)
            );
            if (escrow.voucher721L2() == address(0)) {
                escrow.setVoucherL2(
                    getSafeAddress("Mgd721L2Voucher", chainName),
                    TypeNFT.ERC721
                );
            }
            if (escrow.voucher1155L2() == address(0)) {
                escrow.setVoucherL2(
                    getSafeAddress("Mgd1155L2Voucher", chainName),
                    TypeNFT.ERC1155
                );
            }
        }
        // MgdERC721PermitEscrowable
        if (config.mgd721 == Action.CONFIGURE) {
            MgdERC721PermitEscrowable mgd721 = MgdERC721PermitEscrowable(
                getSafeAddress("MgdERC721PermitEscrowable", chainName)
            );
            mgd721.setMintGoldDustSetPriceAddress(
                getSafeAddress("MintGoldDustSetPrice", chainName)
            );
            mgd721.setMintGoldDustMarketplaceAuctionAddress(
                getSafeAddress("MintGoldDustMarketplaceAuction", chainName)
            );
            if (mgd721.escrow() == address(0)) {
                mgd721.setEscrow(getSafeAddress("MgdL2NFTEscrow", pairChain));
            }
        }
        // MgdERC1155PermitEscrowable
        if (config.mgd1155 == Action.CONFIGURE) {
            MgdERC1155PermitEscrowable mgd1155 = MgdERC1155PermitEscrowable(
                getSafeAddress("MgdERC1155PermitEscrowable", chainName)
            );
            mgd1155.setMintGoldDustSetPriceAddress(
                getSafeAddress("MintGoldDustSetPrice", chainName)
            );
            mgd1155.setMintGoldDustMarketplaceAuctionAddress(
                getSafeAddress("MintGoldDustMarketplaceAuction", chainName)
            );
            if (mgd1155.escrow() == address(0)) {
                mgd1155.setEscrow(getSafeAddress("MgdL2NFTEscrow", pairChain));
            }
        }
        // MintGoldDustSetPrice
        if (config.mgdSetPrice == Action.CONFIGURE) {
            MintGoldDustSetPrice setPrice = MintGoldDustSetPrice(
                getSafeAddress("MintGoldDustSetPrice", chainName)
            );
            setPrice.setMintGoldDustMarketplace(
                getSafeAddress("MintGoldDustMarketplaceAuction", chainName)
            );
        }
        // MintGoldDustMarketplaceAuction
        if (config.mgdAuction == Action.CONFIGURE) {
            MintGoldDustMarketplaceAuction auction = MintGoldDustMarketplaceAuction(
                    getSafeAddress("MintGoldDustMarketplaceAuction", chainName)
                );
            auction.setMintGoldDustMarketplace(
                getSafeAddress("MintGoldDustSetPrice", chainName)
            );
        }
    }

    function getSafeAddress(
        string memory contractLabel,
        string memory chainName
    ) private returns (address) {
        try fs.getAddress(contractLabel, chainName) returns (address addr) {
            return addr;
        } catch {
            revert FileNotFound(chainName, contractLabel);
        }
    }
}
