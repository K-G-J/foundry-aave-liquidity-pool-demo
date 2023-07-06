// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import {Script} from "forge-std/Script.sol";
import {MarketInteractions} from "../src/MarketInteractions.sol";
import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";

// forge script script/MarketInteractions.s.sol --rpc-url $MAINNET_RPC_URL

contract DeployMarketInteractions is Script {
    // Mainnet contracts
    IPoolAddressesProvider addressesProvider = IPoolAddressesProvider(0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e);

    function run() external returns (MarketInteractions marketInteractions) {
        vm.startBroadcast();
        marketInteractions = new MarketInteractions(addressesProvider);
        vm.stopBroadcast();
    }
}
