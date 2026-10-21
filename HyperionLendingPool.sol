// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

contract HyperionLendingPool {
    struct UserPosition {
        uint256 suppliedCollateral;
        uint256 borrowedAmount;
        uint256 lastInterestBlock;
        bool isActive;
    }

    address payable public immutable poolGovernor;
    string public protocolDescriptor;
    uint256 public borrowInterestRateBps; // 500 = 5%
    uint256 public collateralRatioPercent; // 150 = 150% обеспечение
    uint256 public totalLiquiditySupplied;
    uint256 public totalBorrowedCapital;
    bool public isBorrowingHalted;

    mapping(address => UserPosition) public positions;

    event CollateralSupplied(address indexed user, uint256 amount);
    event CollateralWithdrawn(address indexed user, uint256 amount);
    event LoanOriginated(address indexed user, uint256 amount);
    event LoanRepaid(address indexed user, uint256 amount);
    event RateConfigured(uint256 newRateBps, uint256 newCollateralRatio);
    event BorrowStatusSwitched(bool halted);
    event DescriptorChanged(string newDescriptor);
    event ReserveSurplusWithdrawn(address indexed governor, uint256 amount);

    modifier onlyGovernor() {
        require(msg.sender == poolGovernor, "HyperionLending: Unauthorized access");
        _;
    }

    constructor() {
        poolGovernor = payable(msg.sender);
        protocolDescriptor = "Hyperion Base Liquidity Core v1";
        borrowInterestRateBps = 400; // 4%
        collateralRatioPercent = 120; // 120%
        isBorrowingHalted = false;
    }

    // 1. Поставка залоговой ликвидности
    function supplyCollateral() external payable {
        require(msg.value > 0, "HyperionLending: Zero collateral");

        UserPosition storage pos = positions[msg.sender];
        pos.suppliedCollateral += msg.value;
        pos.lastInterestBlock = block.number;
        pos.isActive = true;

        totalLiquiditySupplied += msg.value;
        emit CollateralSupplied(msg.sender, msg.value);
    }

    // 2. Взятие займа под залог
    function borrowFunds(uint256 amount) external {
        require(!isBorrowingHalted, "HyperionLending: Borrowing paused");
        UserPosition storage pos = positions[msg.sender];
        require(pos.isActive, "HyperionLending: Position not found");

        uint256 maxBorrowable = (pos.suppliedCollateral * 100) / collateralRatioPercent;
        require(pos.borrowedAmount + amount <= maxBorrowable, "HyperionLending: Exceeds collateral limit");
        require(address(this).balance >= amount, "HyperionLending: Insufficient pool liquidity");

        pos.borrowedAmount += amount;
        totalBorrowedCapital += amount;

        (bool sent, ) = payable(msg.sender).call{value: amount}("");
        require(sent, "HyperionLending: Borrow payout failed");

        emit LoanOriginated(msg.sender, amount);
    }

    // 3. Погашение займа
    function repayLoan() external payable {
        UserPosition storage pos = positions[msg.sender];
        require(pos.borrowedAmount > 0, "HyperionLending: No active debt");
        require(msg.value > 0, "HyperionLending: Repayment must be positive");

        uint256 repayAmount = msg.value;
        if (repayAmount > pos.borrowedAmount) {
            repayAmount = pos.borrowedAmount;
        }

        pos.borrowedAmount -= repayAmount;
        totalBorrowedCapital -= repayAmount;

        // Возврат сдачи, если переплачено
        if (msg.value > repayAmount) {
            uint256 refund = msg.value - repayAmount;
            (bool refunded, ) = payable(msg.sender).call{value: refund}("");
            require(refunded, "HyperionLending: Refund failed");
        }

        emit LoanRepaid(msg.sender, repayAmount);
    }

    // 4. Частичный или полный вывод залога
    function withdrawCollateral(uint256 amount) external {
        UserPosition storage pos = positions[msg.sender];
        require(pos.suppliedCollateral >= amount, "HyperionLending: Exceeds supplied");

        uint256 remainingCollateral = pos.suppliedCollateral - amount;
        uint256 maxBorrowAllowed = (remainingCollateral * 100) / collateralRatioPercent;
        require(pos.borrowedAmount <= maxBorrowAllowed, "HyperionLending: Collateral factor breached");

        pos.suppliedCollateral -= amount;
        totalLiquiditySupplied -= amount;

        (bool sent, ) = payable(msg.sender).call{value: amount}("");
        require(sent, "HyperionLending: Withdraw failed");

        emit CollateralWithdrawn(msg.sender, amount);
    }

    // 5. Корректировка процентных ставок и требований обеспечения
    function configureParameters(uint256 newRateBps, uint256 newCollateralRatio) external onlyGovernor {
        require(newRateBps <= 2000, "HyperionLending: Rate cap is 20%");
        require(newCollateralRatio >= 110, "HyperionLending: Min collateral ratio 110%");

        borrowInterestRateBps = newRateBps;
        collateralRatioPercent = newCollateralRatio;

        emit RateConfigured(newRateBps, newCollateralRatio);
    }

    // 6. Пауза / включение модуля заимствований
    function setBorrowingHalt(bool halted) external onlyGovernor {
        isBorrowingHalted = halted;
        emit BorrowStatusSwitched(halted);
    }

    // 7. Обновление мета-дескриптора пула
    function updateDescriptor(string calldata newDescriptor) external onlyGovernor {
        require(bytes(newDescriptor).length > 0, "HyperionLending: Empty descriptor");
        protocolDescriptor = newDescriptor;
        emit DescriptorChanged(newDescriptor);
    }

    // 8. Вывод излишков ликвидности / резервов пула
    function sweepSurplus() external onlyGovernor {
        uint256 surplus = address(this).balance > totalLiquiditySupplied ? address(this).balance - totalLiquiditySupplied : 0;
        if (surplus == 0 && address(this).balance > 0 && totalBorrowedCapital == 0) {
            surplus = address(this).balance;
        }
        require(surplus > 0, "HyperionLending: Zero surplus");

        (bool sent, ) = poolGovernor.call{value: surplus}("");
        require(sent, "HyperionLending: Sweep failed");

        emit ReserveSurplusWithdrawn(poolGovernor, surplus);
    }

    // Чтение информации о позиции
    function getPositionDetails(address user) external view returns (
        uint256 collateral,
        uint256 debt,
        uint256 maxAvailableBorrow,
        bool active
    ) {
        UserPosition memory pos = positions[user];
        uint256 maxBorrow = 0;
        if (pos.suppliedCollateral > 0) {
            maxBorrow = (pos.suppliedCollateral * 100) / collateralRatioPercent;
            if (maxBorrow > pos.borrowedAmount) {
                maxBorrow -= pos.borrowedAmount;
            } else {
                maxBorrow = 0;
            }
        }
        return (pos.suppliedCollateral, pos.borrowedAmount, maxBorrow, pos.isActive);
    }
}