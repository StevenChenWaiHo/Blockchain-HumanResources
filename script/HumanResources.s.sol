// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {HumanResources} from "../src/HumanResources.sol";

contract HumanResourcesScript is Script {
    HumanResources public humanResources;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        humanResources = new HumanResources();

        vm.stopBroadcast();
    }
}
