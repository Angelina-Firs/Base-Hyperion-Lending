# Base Hyperion Lending Pool

A robust, decentralized lending and borrowing protocol deployed on the Base L2 network. Hyperion Lending Pool allows users to supply liquidity to earn interest or overcollateralize their assets to borrow against them in a trustless, permissionless environment.

## Core Mechanics
* **Algorithmic Interest Rates:** Borrowing and lending rates dynamically adjust based on pool utilization ratios. High utilization spikes borrowing costs to incentivize new liquidity and protect supplier withdrawals.
* **Automated Liquidations:** Integrates strict collateralization thresholds. If a borrower's health factor drops below `1.0`, liquidators can instantly repay the debt to claim the underlying collateral plus a liquidation bonus.
* **Flash-Loan Resistance:** The protocol utilizes time-weighted average pricing (TWAP) and block-delay constraints to heavily mitigate the risk of flash-loan oracle manipulation during borrowing and liquidation events.

## Architecture
Compiled with Solidity `0.8.37`. The protocol strictly isolates user balance mappings from interest rate mathematical calculations, applying the Checks-Effects-Interactions pattern across all withdrawal and borrow functions to eliminate reentrancy vulnerabilities.
