// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import {IERC20} from "@aave/core-v3/contracts/dependencies/openzeppelin/contracts/IERC20.sol";

contract MarketInteractions {
    //=============== ERRORS ===============//

    error MarketInteractions__invalidAmount();
    error MarketInteractions__invalidAddress();
    error MarketInteractions__notOwner();
    error MarketInteractions__transferFailed();
    error MarketInteractions__zeroTokenBalance();

    //=============== STATE VARIABLES ===============//

    address payable public owner;

    IPoolAddressesProvider public immutable addressesProvider;
    IPool public immutable pool;

    //=============== EVENTS ===============//

    event LiquiditySupplied(address indexed asset, uint256 indexed amount);
    event LiquidityWithdrawn(address indexed asset, uint256 indexed amount);
    event TokensWithdrawn(address indexed token, uint256 indexed amount);

    //=============== MODIFIERS ===============//

    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert MarketInteractions__notOwner();
        }
        _;
    }

    //=============== CONSTRUCTOR ===============//

    constructor(IPoolAddressesProvider _addressesProvider) {
        owner = payable(msg.sender);
        addressesProvider = _addressesProvider;
        pool = IPool(addressesProvider.getPool());
    }

    //=============== FALLBACK ===============//

    receive() external payable {}

    //=============== EXTERNAL FUNCTIONS ===============//

    /**
     * @notice Deposit token into the Aave protocol
     * @dev The caller must approve this contract to spend the token
     * @dev Sends tokens to this contract, caller must withdrawLiquidty and then call withdraw to get them back
     * @param _asset The address of the token to deposit
     * @param _amount The amount of token to deposit
     */
    function supplyLiquidity(address _asset, uint256 _amount) external onlyOwner {
        if (_amount <= 0) {
            revert MarketInteractions__invalidAmount();
        }

        address onBehalfOf = address(this);
        uint16 referralCode = 0;

        emit LiquiditySupplied(_asset, _amount);

        bool success = IERC20(_asset).transferFrom(msg.sender, address(this), _amount);
        if (!success) {
            revert MarketInteractions__transferFailed();
        }

        IERC20(_asset).approve(address(pool), _amount);
        pool.supply(_asset, _amount, onBehalfOf, referralCode);
    }

    /**
     * @notice Withdraw token from the Aave protocol
     * Withdraws an _amount of underlying asset from the reserve, burning the equivalent aTokens owned
     * @param _asset The address of the underlying token to withdraw
     * @param _amount The amount of token to withdraw
     * Send the value type(uint256).max in order to withdraw the whole aToken balance
     */
    function withdrawLiquidity(address _asset, uint256 _amount) external onlyOwner returns (uint256) {
        if (_amount <= 0) {
            revert MarketInteractions__invalidAmount();
        }
        if (_asset == address(0)) {
            revert MarketInteractions__invalidAddress();
        }

        address to = address(this);

        uint256 earned = pool.withdraw(_asset, _amount, to);
        emit LiquidityWithdrawn(_asset, earned);

        return earned;
    }

    /**
     * @notice Withdraw tokens from this contract to the owner
     * @param _token The address of the token to withdraw
     */
    function withdraw(address _token) external onlyOwner {
        if (_token == address(0)) {
            revert MarketInteractions__invalidAddress();
        }

        uint256 balance = getBalance(_token);

        if (balance == 0) {
            revert MarketInteractions__zeroTokenBalance();
        }

        emit TokensWithdrawn(_token, balance);

        bool success = IERC20(_token).transfer(msg.sender, balance);
        if (!success) {
            revert MarketInteractions__transferFailed();
        }
    }

    //=============== VIEW FUNCTIONS ===============//

    /**
     * @notice Returns the balance of the contract for token
     * @param _token The address of the token
     */
    function getBalance(address _token) public view returns (uint256) {
        if (_token == address(0)) {
            revert MarketInteractions__invalidAddress();
        }

        return IERC20(_token).balanceOf(address(this));
    }

    /**
     * @notice Returns the user account data across all the reserves in Aave
     * @param _user The address of the user
     * @return totalCollateralBase The total collateral of the user in the base currency used by the price feed
     * @return totalDebtBase The total debt of the user in the base currency used by the price feed
     * @return availableBorrowsBase The borrowing power left of the user in the base currency used by the price feed
     * @return currentLiquidationThreshold The liquidation threshold of the user
     * @return ltv The loan to value of The user
     * @return healthFactor The current health factor of the user
     */
    function getUserAccountData(address _user)
        external
        view
        returns (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        )
    {
        return pool.getUserAccountData(_user);
    }
}
