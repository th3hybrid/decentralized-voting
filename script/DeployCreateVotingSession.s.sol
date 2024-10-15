// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {CreateVotingSession} from "src/CreateVotingSession.sol";

contract DeployCreateVotingSession is Script {
    CreateVotingSession createVotingSession;

    function run() external returns (CreateVotingSession) {
        vm.startBroadcast();
        createVotingSession = new CreateVotingSession();
        vm.stopBroadcast();
        return createVotingSession;
    }
}
