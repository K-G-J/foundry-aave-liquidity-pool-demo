// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import {Test, console, Vm} from "forge-std/Test.sol";
import {MarketInteractions} from "../src/MarketInteractions.sol";
import {IPool, DataTypes} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import {IERC20} from "@aave/core-v3/contracts/dependencies/openzeppelin/contracts/IERC20.sol";

contract MarketInteractionsTest is Test {
    MarketInteractions marketInteractions;
    IPool public pool;

    // Mainnet contracts
    IPoolAddressesProvider public addressesProvider = IPoolAddressesProvider(0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e);
    IERC20 public link = IERC20(0x514910771AF9Ca656af840dff83E8264EcF986CA);
    IERC20 public aLink = IERC20(0x5E8C8A7243651DB1384C0dDfDbE39761E8e7E51a);

    uint256 public constant INITIAL_LINK_BALANCE = 500e18;
    uint256 public constant LINK_LIQUIDITY_AMOUNT = 100e18;

    address notOwner = makeAddr("notOwner");

    // MarketInteractions Events
    event LiquiditySupplied(address indexed asset, uint256 amount);
    event LiquidityWithdrawn(address indexed asset, uint256 amount);
    event TokensWithdrawn(address indexed token, uint256 amount);

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));

        pool = IPool(addressesProvider.getPool());
        marketInteractions = new MarketInteractions(addressesProvider);

        // Send LINK to this contract
        deal(address(link), address(this), INITIAL_LINK_BALANCE);

        vm.label(address(this), "Owner");
        vm.label(address(marketInteractions), "MarketInteractions");
        vm.label(address(pool), "Pool");
        vm.label(address(link), "LINK");
    }

    //==== Constructor Tests ====//

    function test__constructor() public {
        assertEq(address(this), address(marketInteractions.owner()));
        assertEq(address(addressesProvider), address(marketInteractions.addressesProvider()));
        assertEq(address(pool), address(marketInteractions.pool()));
    }

    //==== Supply Liquidity Tests ====//

    function test__supplyLiquidityNotOwnerReverts() public {
        vm.startPrank(notOwner);
        // Approve LINK for marketInteractions
        link.approve(address(marketInteractions), LINK_LIQUIDITY_AMOUNT);
        // Attempt to supply liquidity
        vm.expectRevert(MarketInteractions.MarketInteractions__notOwner.selector);
        marketInteractions.supplyLiquidity(address(link), LINK_LIQUIDITY_AMOUNT);
        vm.stopPrank();
    }

    function test__supplyLiquidity() public {
        // Approve LINK for marketInteractions
        link.approve(address(marketInteractions), LINK_LIQUIDITY_AMOUNT);
        // Supply liquidity
        marketInteractions.supplyLiquidity(address(link), LINK_LIQUIDITY_AMOUNT);
        // Check LINK and aLINK balances
        assertEq(link.balanceOf(address(this)), INITIAL_LINK_BALANCE - LINK_LIQUIDITY_AMOUNT);
        assertEq(marketInteractions.getBalance(address(link)), 0);
        assertEq(marketInteractions.getBalance(address(aLink)), LINK_LIQUIDITY_AMOUNT);
    }

    modifier liquiditySupplied() {
        link.approve(address(marketInteractions), LINK_LIQUIDITY_AMOUNT);
        marketInteractions.supplyLiquidity(address(link), LINK_LIQUIDITY_AMOUNT);
        _;
    }

    function test__supplyLiquidityEvent() public {
        link.approve(address(marketInteractions), LINK_LIQUIDITY_AMOUNT);
        vm.recordLogs();
        marketInteractions.supplyLiquidity(address(link), LINK_LIQUIDITY_AMOUNT);
        // Check event
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 9);
        assertEq(logs[0].topics[0], keccak256("LiquiditySupplied(address,uint256)"));
        assertEq(logs[0].topics[1], bytes32(uint256(uint160(address(link)))));
        assertEq(logs[0].topics[2], bytes32(LINK_LIQUIDITY_AMOUNT));
    }

    //==== Withdraw Liquidity Tests ====//

    function test__withdrawLiquidityNotOwnerReverts() public liquiditySupplied {
        vm.startPrank(notOwner);
        // Attempt to withdraw liquidity
        vm.expectRevert(MarketInteractions.MarketInteractions__notOwner.selector);
        marketInteractions.withdrawLiquidity(address(link), type(uint256).max);
        vm.stopPrank();
    }

    function test__withdrawLiquidity() public liquiditySupplied {
        // Withdraw liquidity (send the value type(uint256).max in order to withdraw the whole aToken balance)
        marketInteractions.withdrawLiquidity(address(link), type(uint256).max);
        // Check LINK and aLINK balances
        assertEq(marketInteractions.getBalance(address(link)), LINK_LIQUIDITY_AMOUNT);
        assertEq(marketInteractions.getBalance(address(aLink)), 0);
    }

    function test__withdrawLiquidityWithInterest() public liquiditySupplied {
        DataTypes.ReserveData memory reserveData = pool.getReserveData(address(link));
        uint256 liquidityRate = reserveData.currentLiquidityRate; // Ray units = 1e27

        // Earn interest APY and then withdraw liquidity
        vm.roll(block.timestamp + 365 days);
        vm.warp(block.timestamp + 365 days);

        uint256 aLinkBalance = marketInteractions.getBalance(address(aLink));
        uint256 actualLinkInterestEarned = aLinkBalance - LINK_LIQUIDITY_AMOUNT;
        uint256 approxLinkInterestEarned = (LINK_LIQUIDITY_AMOUNT * liquidityRate) / 1e27;
        assertGt(actualLinkInterestEarned, 0);
        assertApproxEqRel(actualLinkInterestEarned, approxLinkInterestEarned, 0.01e18); // 1% tolerance

        marketInteractions.withdrawLiquidity(address(link), type(uint256).max);
        // Check LINK and aLINK balances
        assertEq(marketInteractions.getBalance(address(link)), aLinkBalance);
        assertEq(marketInteractions.getBalance(address(aLink)), 0);
    }

    function test__withdrawLiquidityEvent() public liquiditySupplied {
        vm.recordLogs();
        uint256 earned = marketInteractions.withdrawLiquidity(address(link), type(uint256).max);
        // Check event
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs[6].topics[0], keccak256("LiquidityWithdrawn(address,uint256)"));
        assertEq(logs[6].topics[1], bytes32(uint256(uint160(address(link)))));
        assertEq(logs[6].topics[2], bytes32(earned));
    }

    //==== Withdraw Tests ====//

    function test__withdrawZeroTokenBalanceReverts() public {
        vm.expectRevert(MarketInteractions.MarketInteractions__zeroTokenBalance.selector);
        marketInteractions.withdraw(address(link));
    }

    function test__withdrawNotOwnerReverts() public liquiditySupplied {
        marketInteractions.withdrawLiquidity(address(link), type(uint256).max);
        vm.startPrank(notOwner);
        // Attempt to withdraw
        vm.expectRevert(MarketInteractions.MarketInteractions__notOwner.selector);
        marketInteractions.withdraw(address(link));
        vm.stopPrank();
    }

    function test__withdraw() public liquiditySupplied {
        uint256 linkBalance = marketInteractions.withdrawLiquidity(address(link), type(uint256).max);
        // Check LINK and aLINK balances
        assertEq(marketInteractions.getBalance(address(link)), linkBalance);
        assertEq(marketInteractions.getBalance(address(aLink)), 0);
        // Withdraw LINK to owner
        marketInteractions.withdraw(address(link));
        // Check LINK balance
        assertEq(link.balanceOf(address(this)), INITIAL_LINK_BALANCE - LINK_LIQUIDITY_AMOUNT + linkBalance);
        assertEq(marketInteractions.getBalance(address(link)), 0);
    }

    function test__withdrawEvent() public liquiditySupplied {
        uint256 linkBalance = marketInteractions.withdrawLiquidity(address(link), type(uint256).max);
        vm.recordLogs();
        marketInteractions.withdraw(address(link));
        // Check event
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs[0].topics[0], keccak256("TokensWithdrawn(address,uint256)"));
        assertEq(logs[0].topics[1], bytes32(uint256(uint160(address(link)))));
        assertEq(logs[0].topics[2], bytes32(linkBalance));
    }
}
