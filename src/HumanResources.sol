// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import "./HumanResourcesInterface.sol";
import {IERC20} from "lib/forge-std/src/interfaces/IERC20.sol";
import {IWETH} from "./interfaces/IWETH.sol";
import {AggregatorV3Interface} from "lib/chainlink/interfaces/AggregatorV3Interface.sol";
import {ISwapRouter} from "./interfaces/ISwapRouter.sol";
import "forge-std/console.sol";

contract HumanResources is IHumanResources {
    address internal constant _USDC = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85;
    address internal constant _WETH = 0x4200000000000000000000000000000000000006;
    address internal constant _Oracle = 0x13e3Ee699D1909E989722E753853AE30b17e08c5;
    AggregatorV3Interface internal constant _ETH_USD_FEED = AggregatorV3Interface(_Oracle);
    address internal constant _Uniswap = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    ISwapRouter internal swapRouter = ISwapRouter(_Uniswap);

    uint256 private acceptableSlippage = 2; // in percentage

    address public hrManager;
    uint256 public activeEmployeeCount;

    IERC20 private usdc = IERC20(_USDC); // 6 decimals
    IWETH private weth = IWETH(_WETH);

    mapping(address => Employee) private employees;

    struct Employee {
        uint256 weeklyUsdSalary; // Scaled with 18 decimals
        uint256 employedSince; // Latest register timestamp
        uint256 terminatedAt; // Latest terminate timestamp
        uint256 pendingSalary; // Non withdrawn salary accumulated until termination
        uint256 lastWithdrawal; // Latest withdraw timestamp
        bool active; // Employee active status
        bool isEth; // Employee prefer withdrawing ETH
    }

    constructor() {
        hrManager = msg.sender;
    }

    modifier onlyHRManager() {
        if (msg.sender != hrManager) revert NotAuthorized();
        _;
    }

    modifier onlyEmployee() {
        if (employees[msg.sender].employedSince == 0) revert NotAuthorized();
        _;
    }

    modifier onlyActiveEmployee() {
        if (!employees[msg.sender].active) revert NotAuthorized();
        _;
    }

    // 2. Registering and Managing Employees
    function registerEmployee(address employee, uint256 weeklyUsdSalary) external override onlyHRManager {
        Employee storage emp = employees[employee];
        if (employees[employee].active) {
            revert EmployeeAlreadyRegistered();
        }

        activeEmployeeCount += 1;

        // console.log("registered pending Salary: ", employees[employee].pendingSalary);

        emp.weeklyUsdSalary = weeklyUsdSalary;
        emp.employedSince = block.timestamp;
        emp.lastWithdrawal = block.timestamp;
        emp.terminatedAt = 0;
        emp.active = true;

        emit EmployeeRegistered(employee, weeklyUsdSalary);
    }

    function convertSalaryToUSDC(uint256 salary) public pure returns (uint256) {
        return salary / 1e12;
    }

    function convertSalaryToETH(uint256 salary) public view returns (uint256) {
        console.log("USDC Amount", salary);
        uint256 ethPrice = getEthPrice();
        console.log("ETH Price", ethPrice);
        uint256 ethAmount = salary * 1e18 / ethPrice;
        console.log("ETH Amount", ethAmount);
        return ethAmount;
    }

    // Calculate Salary in 18 decimals
    function calculateSalary(Employee memory employee) private view returns (uint256 salary) {
        if (employee.employedSince == 0) revert EmployeeNotRegistered();

        uint256 amount = 0;

        if (employee.active) {
            uint256 elapsedTime = block.timestamp - employee.lastWithdrawal;
            amount = (elapsedTime * employee.weeklyUsdSalary / (7 days));
        }
        console.log("accumulated salary: ", amount);
        console.log("pending salary: ", employee.pendingSalary);

        amount += employee.pendingSalary;

        return amount;
    }

    function terminateEmployee(address employee) external override onlyHRManager {
        Employee storage emp = employees[employee];
        if (emp.employedSince == 0 || !emp.active) {
            revert EmployeeNotRegistered();
        }

        emp.pendingSalary += calculateSalary(emp);
        emp.lastWithdrawal = block.timestamp;
        emp.terminatedAt = block.timestamp;
        emp.active = false;

        activeEmployeeCount -= 1;
        emit EmployeeTerminated(employee);
    }

    function getEthPrice() internal view returns (uint256) {
        (, int256 answer,,,) = _ETH_USD_FEED.latestRoundData();
        uint256 feedDecimals = _ETH_USD_FEED.decimals();
        uint256 ethPrice = uint256(answer) * 10 ** (18 - feedDecimals); // price in 18 decimals
        return ethPrice;
    }

    function swapUSDCToETH(uint256 salary) internal returns (uint256) {
        uint256 ethAmount = convertSalaryToETH(salary);

        // Use Uniswap to perform the swap
        usdc.approve(_Uniswap, convertSalaryToUSDC(salary));
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: _USDC, // Swap USDC
            tokenOut: _WETH, // to WETH
            fee: 500, // 0.05% for low-volatility pairs
            recipient: address(this), // WETH to this account
            deadline: block.timestamp + 5 minutes, // Low duration to protect against large market movement
            amountIn: convertSalaryToUSDC(salary), // The amount of USDC to swap
            amountOutMinimum: ethAmount * (100 - acceptableSlippage) / 100, // Minimum should be 2% less of expected amount
            sqrtPriceLimitX96: 0 // Rely amountOutMinimum to handle slippage
        });

        return swapRouter.exactInputSingle(params);
    }

    function withdrawSalaryHelper(address addr) private {
        Employee storage emp = employees[addr];
        uint256 amount = calculateSalary(emp);

        uint256 usdcAmount = convertSalaryToUSDC(amount);
        require(usdc.balanceOf(address(this)) >= usdcAmount, "Insufficient balance");

        emp.lastWithdrawal = block.timestamp;
        emp.pendingSalary = 0;

        if (emp.isEth) {
            uint256 ethAmount = swapUSDCToETH(amount);
            weth.withdraw(ethAmount);
            (bool sent,) = addr.call{value: ethAmount}("");
            require(sent, "Failed to send Ether");
            emit SalaryWithdrawn(addr, true, ethAmount);
        } else {
            bool sent = usdc.transfer(addr, usdcAmount);
            require(sent, "Failed to send USDC");
            emit SalaryWithdrawn(addr, false, usdcAmount);
        }
    }

    function withdrawSalary() external override onlyEmployee {
        withdrawSalaryHelper(msg.sender);
    }

    function getActiveEmployeeCount() external view override returns (uint256) {
        return activeEmployeeCount;
    }

    function switchCurrency() external override onlyActiveEmployee {
        withdrawSalaryHelper(msg.sender);
        Employee storage emp = employees[msg.sender];

        emp.isEth = !emp.isEth;
        emit CurrencySwitched(msg.sender, emp.isEth);
    }

    function salaryAvailable(address employee) external view override returns (uint256) {
        Employee memory emp = employees[employee];
        uint256 amount = calculateSalary(emp);
        if (emp.isEth) {
            amount = convertSalaryToETH(amount);
        } else {
            amount = convertSalaryToUSDC(amount);
        }
        return amount;
    }

    function getEmployeeInfo(address employee)
        external
        view
        override
        returns (uint256 weeklySalary, uint256 employedSince, uint256 terminatedAt)
    {
        Employee memory emp = employees[employee];
        return (emp.weeklyUsdSalary, emp.employedSince, emp.terminatedAt);
    }

    receive() external payable {}

    fallback() external payable {}
}
