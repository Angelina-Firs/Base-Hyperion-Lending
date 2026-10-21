// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;
interface IHyperionLendingPool {
    function supplyLiquidity(address asset, uint256 amount) external payable;
    function borrowAsset(address asset, uint256 amount) external;
    function liquidatePosition(address user, address debtAsset) external;
}
