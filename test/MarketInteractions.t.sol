// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import {Test, console} from "forge-std/Test.sol";
import {MarketInteractions} from "../src/MarketInteractions.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import {IERC20} from "@aave/core-v3/contracts/dependencies/openzeppelin/contracts/IERC20.sol";

contract MarketInteractionsTest is Test {
    MarketInteractions marketInteractions;
    IPool public pool;

    // Mainnet contracts
    IPoolAddressesProvider public addressesProvider = IPoolAddressesProvider(0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e);
    IERC20 public link = IERC20(0x514910771AF9Ca656af840dff83E8264EcF986CA);

    uint256 public constant INITIAL_LINK_BALANCE = 500e18;
    uint256 public constant LINK_LIQUIDITY_AMOUNT = 1000e18;

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));

        pool = IPool(addressesProvider.getPool());
        marketInteractions = new MarketInteractions(addressesProvider, link);

        // Send LINK to the marketInteractions contract
        deal(address(link), address(marketInteractions), INITIAL_LINK_BALANCE);
    }

    function test__constructor() public {
        assertEq(address(this), address(marketInteractions.owner()));
        assertEq(address(addressesProvider), address(marketInteractions.addressesProvider()));
        assertEq(address(pool), address(marketInteractions.pool()));
        assertEq(address(link), address(marketInteractions.link()));
    }
}
