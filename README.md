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
1. All salary is stored in 18 decimals format, it is converted to USDC and ETH with convertSalaryToUSDC() and swapUSDCToETH()

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
2. Invert isEth in Employee

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
Convert salary to ETH by checking the current ETH/USD price on an oracle with getEthPrice()

## Salary Calculations

### calculateSalary(Employee memory employee)

## Swapping Currency

### getEthPrice()

### swapUSDCToETH(uint256 salary)


## Withdrawal 
### withdrawSalaryHelper(address addr)

