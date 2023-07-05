// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import {Script} from "forge-std/Script.sol";
import {MarketInteractions} from "../src/MarketInteractions.sol";
import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import {IERC20} from "@aave/core-v3/contracts/dependencies/openzeppelin/contracts/IERC20.sol";

// forge script script/MarketInteractions.s.sol --rpc-url $MAINNET_RPC_URL

contract DeployMarketInteractions is Script {
    // Mainnet contracts
    IPoolAddressesProvider addressesProvider = IPoolAddressesProvider(0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e);
    IERC20 public link = IERC20(0x514910771AF9Ca656af840dff83E8264EcF986CA);

    function run() external returns (MarketInteractions marketInteractions) {
        vm.startBroadcast();
        marketInteractions = new MarketInteractions(addressesProvider, link);
        vm.stopBroadcast();
    }
}
