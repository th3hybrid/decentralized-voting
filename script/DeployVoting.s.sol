// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {Voting} from "src/Voting.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "script/Interactions.s.sol";

contract DeployVoting is Script {
    function run(
        address[] memory _candidates,
        uint256 _interval
    ) external returns (Voting, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        //local -> deploy mocks,get local config
        //base sepolia -> get base sepolia config
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        if (config.subscriptionId == 0) {
            //create subscription
            CreateSubscription createSubscription = new CreateSubscription();
            (config.subscriptionId, config.vrfCoordinator) = createSubscription
                .createSubscription(config.vrfCoordinator, config.account);

            //fund it
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                config.vrfCoordinator,
                config.subscriptionId,
                config.link,
                config.account
            );
        }

        vm.startBroadcast(config.account);
        Voting voting = new Voting(
            config.vrfCoordinator,
            config.gasLane,
            config.subscriptionId,
            config.callbackGasLimit,
            _candidates,
            _interval
        );
        vm.stopBroadcast();

        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(
            address(voting),
            config.vrfCoordinator,
            config.subscriptionId,
            config.account
        );
        return (voting, helperConfig);
    }
}
