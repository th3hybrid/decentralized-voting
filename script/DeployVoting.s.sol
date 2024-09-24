// SPDX-License-Identifier: MIT

pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {Voting} from "src/Voting.sol";

contract DeployVoting is Script {
    address[] private CANDIDATES = [
        0xdD870fA1b7C4700F2BD7f44238821C26f7392148,
        0x583031D1113aD414F02576BD6afaBfb302140225
    ];
    uint256 private constant INTERVAL = 360;

    function run() external returns (Voting) {
        vm.startBroadcast();
        Voting voting = new Voting(CANDIDATES, INTERVAL);
        vm.stopBroadcast();
        return voting;
    }
}
