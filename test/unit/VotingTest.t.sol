// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {Voting} from "src/Voting.sol";
import {DeployVoting} from "script/DeployVoting.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {CodeConstants} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";

contract VotingTest is CodeConstants, Test {
    Voting voting;
    DeployVoting deployer;
    HelperConfig public helperConfig;
    address public vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;

    address public USER = makeAddr("user");
    address public HYBRID = makeAddr("hybrid");
    address[] public candidates = [
        0xdD870fA1b7C4700F2BD7f44238821C26f7392148,
        0x583031D1113aD414F02576BD6afaBfb302140225
    ];
    address public candidateOne = 0xdD870fA1b7C4700F2BD7f44238821C26f7392148;
    address public candidateTwo = 0x583031D1113aD414F02576BD6afaBfb302140225;
    uint256 private interval = 360;

    function setUp() public {
        deployer = new DeployVoting();
        (voting, helperConfig) = deployer.run(candidates, interval);
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        subscriptionId = config.subscriptionId;
        callbackGasLimit = config.callbackGasLimit;
    }

    modifier voteCandidateOne() {
        voting.vote(candidateOne, USER);
        _;
    }

    function testCanVote() public voteCandidateOne {
        //arrange/act/assert
        assertEq(voting.getVoteStatus(USER), true);
        assert(voting.checkVotes(candidateOne) == 1);
    }

    function testCanOnlyVoteOnce() public voteCandidateOne {
        //arrange/act/assert
        vm.expectRevert(Voting.Voting__CanOnlyVoteOnce.selector);
        voting.vote(candidateTwo, USER);
    }

    function testCanSelectWinner() public voteCandidateOne {
        //arrange
        uint256 additionalVoters = 2;
        uint256 startingIndex;
        //act

        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalVoters;
            i++
        ) {
            address newVoter = address(uint160(i));
            voting.vote(candidateTwo, newVoter);
        }

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        voting.selectWinner();
        address winner = voting.getWinner();
        //assert
        assert(winner == candidateTwo);
    }

    function testCanRandomlyChooseWinnerFromTie() public voteCandidateOne {
        if (block.chainid != LOCAL_CHAIN_ID) {
            return;
        }
        //arrange/act
        voting.vote(candidateTwo, HYBRID);
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        vm.recordLogs();
        voting.selectWinner();
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(voting)
        );
        address winner = voting.getWinner();
        console.log(winner);
    }

    function testCanOnlySelectWinnerWhenTimeHasElapsed()
        public
        voteCandidateOne
    {
        //arrange
        uint256 additionalVoters = 2;
        uint256 startingIndex;
        //act

        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalVoters;
            i++
        ) {
            address newVoter = address(uint160(i));
            voting.vote(candidateTwo, newVoter);
        }

        vm.expectRevert(Voting.Voting__TimeHasNotElapsed.selector);
        voting.selectWinner();
    }

    function testCanGetCandidates() public view {
        address[] memory candidare = voting.getCandidates();
        console.log(candidare[1]);
    }

    function testCannotVoteAfterTimeHasElapsed() public {
        //arrange/act
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        vm.expectRevert(Voting.Voting__TimeHasElapsed.selector);
        voting.vote(candidateOne, USER);
        //assert
        assertEq(voting.getVoteStatus(USER), false);
        assert(voting.checkVotes(candidateOne) == 0);
        console.log(
            voting.getVoteStatus(USER),
            voting.checkVotes(candidateOne)
        );
    }

    function testCanOnlyVoteForRegisteredCandidates() public {
        //arrange/act
        vm.expectRevert(Voting.Voting__InvalidCandidate.selector);
        voting.vote(USER, HYBRID);
    }
}
