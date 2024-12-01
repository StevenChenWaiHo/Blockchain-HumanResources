// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import "./HumanResourcesInterface.sol";
import {IERC20} from "lib/forge-std/src/interfaces/IERC20.sol";
import {AggregatorV3Interface} from "lib/chainlink/interfaces/AggregatorV3Interface.sol";

contract HumanResources is IHumanResources {

    address internal constant _WETH = 0x4200000000000000000000000000000000000006;
    address internal constant _USDC = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85;
    AggregatorV3Interface internal constant _ETH_USD_FEED = AggregatorV3Interface(0x13e3Ee699D1909E989722E753853AE30b17e08c5);
    
    address public hrManager;
    uint256 public activeEmployeeCount;

    IERC20 private usdc;

    mapping(address => Employee) private employees;

    struct Employee {
        uint256 weeklyUsdSalary;
        uint256 employedSince;
        uint256 terminatedAt;
        uint256 pendingSalary;
        uint256 lastWithdrawal;
        bool isEth;
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
        if (employees[msg.sender].employedSince == 0 || employees[msg.sender].terminatedAt != 0) revert NotAuthorized();
        _;
    }

    // 2. Registering and Managing Employees
    function registerEmployee(address employee, uint256 weeklyUsdSalary) external override onlyHRManager {
        if (employees[employee].employedSince != 0){
            revert EmployeeAlreadyRegistered();
        }

        activeEmployeeCount += 1;

        employees[employee] = Employee({
            weeklyUsdSalary: weeklyUsdSalary,
            employedSince: block.timestamp,
            terminatedAt: 0,
            pendingSalary: 0,
            lastWithdrawal: block.timestamp,
            isEth: false
        });
        
        emit EmployeeRegistered(employee, weeklyUsdSalary);
    }

    function calculateSalary(Employee memory employee) private view returns (uint256 salary) {
        if (employee.employedSince == 0) return 0;

        uint256 elapsedTime = block.timestamp - employee.lastWithdrawal;
        uint256 salaryPerSecond = employee.weeklyUsdSalary / (7 days);

        return elapsedTime * salaryPerSecond + employee.pendingSalary;
    }

    function terminateEmployee(address employee) external override onlyHRManager {
        Employee memory emp = employees[employee];
        if (emp.employedSince == 0 || emp.terminatedAt == 0){
            revert EmployeeNotRegistered();
        }

        emp.pendingSalary += calculateSalary(emp);
        emp.lastWithdrawal = block.timestamp;
        emp.terminatedAt = block.timestamp;

        activeEmployeeCount -= 1;

        emit EmployeeTerminated(employee);
    }

    function convertUsdToEth(uint256 usdAmount) private returns (uint256 ethAmount) {

    }

    function withdrawSalaryHelper(address addr) private {
        Employee memory emp = employees[addr];

        uint256 amount = calculateSalary(emp);
        emp.lastWithdrawal = block.timestamp;
        emp.pendingSalary = 0;

        // TODO: Transfer money
        if (emp.isEth) {
            uint256 ethAmount = convertUsdToEth(amount);
            require(address(this).balance >= ethAmount, "Insufficient ETH balance");
            payable(msg.sender).transfer(ethAmount);
            emit SalaryWithdrawn(msg.sender, true, ethAmount);
        } else {
            require(usdc.balanceOf(address(this)) >= amount, "Insufficient USDC balance");
            usdc.transfer(msg.sender, amount);
            emit SalaryWithdrawn(msg.sender, false, amount);
        }


        emit SalaryWithdrawn(addr , emp.isEth, amount);
    }

    function withdrawSalary() external override onlyEmployee {
        withdrawSalaryHelper(msg.sender);
    }

    function getActiveEmployeeCount()
        external
        view
        override
        returns (uint256)
    {
        return activeEmployeeCount;
    }

    function switchCurrency() external override onlyActiveEmployee {
        withdrawSalaryHelper(msg.sender);
        Employee memory emp = employees[msg.sender];

        emp.isEth = !emp.isEth;
        emit CurrencySwitched(msg.sender, emp.isEth);
    }

    function salaryAvailable(address employee) external view override returns (uint256) {
        Employee memory emp = employees[employee];
        return calculateSalary(emp);
    }

    function getEmployeeInfo(address employee)
        external
        view
        override
        returns (
            uint256 weeklySalary,
            uint256 employedSince,
            uint256 terminatedAt
        )
    {
        Employee memory emp = employees[employee];
        return (emp.weeklyUsdSalary, emp.employedSince, emp.terminatedAt);
    }
}
