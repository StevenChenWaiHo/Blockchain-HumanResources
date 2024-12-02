# Struct
```
struct Employee {
    uint256 weeklyUsdSalary; // Scaled with 18 decimals
    uint256 employedSince; // Latest register timestamp
    uint256 terminatedAt; // Latest terminate timestamp
    uint256 pendingSalary; // Non withdrawn salary accumulated until termination
    uint256 lastWithdrawal; // Latest withdraw timestamp
    bool active; // Employee active status
    bool isEth; // Employee prefer withdrawing ETH
}
```

# Implementation
1. All salary is stored and calculated in 18 decimals format, it is then converted to USDC and ETH with convertSalaryToUSDC() and swapUSDCToETH()

# Functions
## Authentication (Modifiers)
### onlyHRManger()
Functions only HR Manager can access

### onlyEmployee()
Functions only active employee can access

### onlyActiveEmployee()
Functions only active employee (non-terminated) can access

## Registering and Managing Employees
### registerEmployee(address employee, uint256 weeklyUsdSalary)
Access: only HR manager

1. Checks if the address is already registered. Revert with EmployeeAlreadyRegistered() if yes.
2. Increment activeEmployeeCount
3. Initialize employee information (pendingSalary is not Initialize for reregistered employees)

### terminateEmployee(address employee)
Access: only HR manager

1. Check if the address is registered or terminated. Revert with EmployeeNotRegistered() if not registered or terminated.
2. Calculate and store pending salary until termination
3. Update withdraw and termination timestamp, set active as false, decrement activeEmployeeCount 

## Withdrawal
### withdrawSalary()
Access: Only Employee (Active and Inactive)

1. Calls withdrawSalaryHelper() with address msg.sender

## Switch Currency
Access: Only Active Employee

1. Withdraw salary with withdrawSalaryHelper()
2. Invert isEth flag in Employee

## Views and Employee Information
### salaryAvailable()
Calculate salary with calculateSalary() and return amount in preferred currency using convertSalaryToUSDC() and swapUSDCToETH()

### hrManager()
Return hr manager address using default view function

### getActiveEmployeeCount()
Return activeEmployeeCount

### getEmployeeInfo(address employee)
Return employee information

# Helper Functions
## Convert Currency
Salary is stored in 18 decimals format, these functions convert the stored salary to the desire currency

### convertSalaryToUSDC(uint256 salary)
Convert salary to USDC by dividing 1e12

### convertSalaryToETH(uint256 salary)
Convert salary to ETH
1. Get the latest ETH/USD price in an oracle
2. Get the number of decimal places the price from the oracle has
3. Divide salary in USDC (18 decimals) by ethPrice (18 decimals) and scale the value to 18 decimals format

## Salary Calculations

### calculateSalary(Employee memory employee)
It returns the salary amount available to withdraw of an employee in 18 decimals

1. Check if employee is registered. Revert with EmployeeNotRegistered() if not.
2. If the employee is active, calculate the accumulated salary by getting the time elapsed since the last withdrawal and multiply it by its salary rate.
3. Finally add the pending salary, which an employee hasn't collected after a termination.

## Swapping Currency

### getEthPrice()
Get the ETH/USDC price from an oracle and scale the value to 18 decimals format.

### swapUSDCToETH(uint256 salary)
Swap USDC to ETH for the contract account

1. Calculate the amount ETH we should get after swapping the salary (in USDC) by checking the price and converting to ETH with convertSalaryToETH().
2. Approves Uniswap router to spend the USDC amount for the swap
3. Input the parameters for the swap routers
```
{
    tokenIn: _USDC, // Swap USDC
    tokenOut: _WETH, // to WETH
    fee: 500, // 0.05% for low-volatility pairs
    recipient: address(this), // WETH to this account
    deadline: block.timestamp + 5 minutes, // Low duration to protect against large market movement
    amountIn: convertSalaryToUSDC(salary), // The amount of USDC to swap
    amountOutMinimum: ethAmount * (100 - acceptableSlippage) / 100, // Minimum should be 2% less of expected amount
    sqrtPriceLimitX96: 0 // Rely amountOutMinimum to handle slippage
}
```

4. Get the amount of ETH received from the swap

## Withdrawal 
### withdrawSalaryHelper(address addr)
Withdraw all salaries available for this employee with their preferred currency.

1. Calculate the salary available for this employee
2. Check the HR contract have enough USDC balance to withdraw
3. Reset pending salary and set last withdrawal timestamp of the employee
4. Transfer salary to the employee address with respect to their desired currency (swap USDC to ETH with swapUSDCToETH() for ETH).

