// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import {IERC20} from "@aave/core-v3/contracts/dependencies/openzeppelin/contracts/IERC20.sol";

contract MarketInteractions {
    //=============== ERRORS ===============//

    error MarketInteractions__notOwner();

    //=============== STATE VARIABLES ===============//

    address payable public owner;

    IPoolAddressesProvider public immutable addressesProvider;
    IPool public immutable pool;

    IERC20 public immutable link;

    //=============== MODIFIERS ===============//

    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert MarketInteractions__notOwner();
        }
        _;
    }

    //=============== CONSTRUCTOR ===============//

    constructor(IPoolAddressesProvider _addressesProvider, IERC20 _link) {
        owner = payable(msg.sender);
        addressesProvider = _addressesProvider;
        pool = IPool(addressesProvider.getPool());
        link = _link;
    }

    //=============== FALLBACK ===============//

    receive() external payable {}

    //=============== EXTERNAL FUNCTIONS ===============//

    /**
     * @notice Deposit token into the Aave protocol
     * @param _asset The address of the token to deposit
     * @param _amount The amount of token to deposit
     */
    function supplyLiquidity(address _asset, uint256 _amount) external {
        address onBehalfOf = address(this);
        uint16 referralCode = 0;

        pool.supply(_asset, _amount, onBehalfOf, referralCode);
    }

    /**
     * @notice Withdraw token from the Aave protocol
     * @param _asset The address of the underlying token to withdraw
     * @param _amount The amount of token to withdraw
     * Send the value type(uint256).max in order to withdraw the whole aToken balance
     */
    function withdrawLiquidity(address _asset, uint256 _amount) external returns (uint256) {
        address to = address(this);

        return pool.withdraw(_asset, _amount, to);
    }

    /**
     * @notice Withdraw tokens from this contract to the owner
     * @param _tokenAddress The address of the token to withdraw
     */
    function withdraw(address _tokenAddress) external onlyOwner {
        IERC20 token = IERC20(_tokenAddress);
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }

    function approveLINK(uint256 _amount, address _poolContractAddress) external returns (bool) {
        return link.approve(_poolContractAddress, _amount);
    }

    //=============== VIEW FUNCTIONS ===============//

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

    /**
     * @notice Returns the allowance of the pool contract for LINK token
     * @param _poolContract The address of the pool contract
     */
    function allowanceLINK(address _poolContract) external view returns (uint256) {
        return link.allowance(address(this), _poolContract);
    }

    /**
     * @notice Returns the balance of the contract for token
     * @param _token The address of the token
     */
    function getBalance(address _token) external view returns (uint256) {
        return IERC20(_token).balanceOf(address(this));
    }
}
