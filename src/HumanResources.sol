// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.1;

import './HumanResourcesInterface.sol';
contract HumanResources is IHumanResources {
    address public hrManager;

    constructor(address addr) {
        hrManager = addr;
    }

    function registerEmployee() external override {
        emit EmployeeRegistered(msg.sender, true);
    }

    function terminateEmployee() external override {}

    function withdrawSalary() external override {}

    function getActiveEmployeeCount() external view override  returns (uint256) { }

    function getEmployeeInfo() external view override {}

    function switchCurrency() external override {}

    function salaryAvailable() external view override returns (uint256) {}
}