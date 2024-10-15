// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {CreateVotingSession} from "src/CreateVotingSession.sol";
import {DeployCreateVotingSession} from "script/DeployCreateVotingSession.s.sol";
import {Voting} from "src/Voting.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {CodeConstants} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract CreateVotingSessionTest is Test, CodeConstants {
    CreateVotingSession votingInstance;
    DeployCreateVotingSession deployer;

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
        deployer = new DeployCreateVotingSession();
        votingInstance = deployer.run();
    }

    function testCanCreateVotingSession() public {
        //arrange/act
        votingInstance.createVotingSession(candidates, interval);
        Voting currentVotingSession = votingInstance.currentVotingSession();
        Voting createdVotingSession = votingInstance.getVoteSession(1);

        //assert
        assertEq(1, votingInstance.getVotingSessionId());
        assertEq(address(createdVotingSession), address(currentVotingSession));
        assert(address(createdVotingSession) != address(0));
        console.log(
            address(createdVotingSession),
            address(currentVotingSession)
        );
    }

    function testCannotCreateVotingSessionWhileAnotherIsActive() public {
        //arrange/act/assert
        votingInstance.createVotingSession(candidates, interval);
        vm.expectRevert(
            CreateVotingSession
                .CreateVotingSession__VoteSessionStillActive
                .selector
        );
        votingInstance.createVotingSession(candidates, interval);
    }

    function testCanVote__createVotingSession() public {
        //arrange/act
        votingInstance.createVotingSession(candidates, interval);
        vm.prank(USER);
        votingInstance.vote(candidateOne);
        //assert
        assertEq(votingInstance.getVoteStatus(USER), true);
        assert(votingInstance.checkVotes(candidateOne) == 1);
    }

    function testCanOnlyVoteOnce__createVotingSession() public {
        //arrange
        votingInstance.createVotingSession(candidates, interval);
        vm.prank(USER);
        //act/assert
        votingInstance.vote(candidateOne);
        vm.expectRevert(Voting.Voting__CanOnlyVoteOnce.selector);
        vm.prank(USER);
        votingInstance.vote(candidateTwo);
    }

    function testCanSelectWinner__createVotingSession() public {
        votingInstance.createVotingSession(candidates, interval);
        //arrange
        uint256 additionalVoters = 2;
        uint256 startingIndex;
        vm.prank(USER);
        //act
        votingInstance.vote(candidateTwo);

        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalVoters;
            i++
        ) {
            address newVoter = address(uint160(i));
            vm.prank(newVoter);
            votingInstance.vote(candidateOne);
        }

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        votingInstance.selectWinner();
        address winner = votingInstance.getWinner();
        //assert
        assert(winner == candidateOne);
    }

    /*function testCanRandomlyChooseWinnerFromTie() public {
        votingInstance.createVotingSession(candidates, interval);
        if (block.chainid != LOCAL_CHAIN_ID) {
            return;
        }
        //arrange/act
        vm.prank(USER);
        votingInstance.vote(candidateTwo);
        vm.prank(HYBRID);
        votingInstance.vote(candidateOne);
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        vm.recordLogs();
        votingInstance.selectWinner();
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(votingInstance)
        );
        address winner = votingInstance.getWinner();
        console.log(winner);
    }*/

    function testCanOnlySelectWinnerWhenTimeHasElapsed__createVotingSession()
        public
    {
        //arrange
        votingInstance.createVotingSession(candidates, interval);
        uint256 additionalVoters = 2;
        uint256 startingIndex;
        vm.prank(USER);
        //act
        votingInstance.vote(candidateTwo);

        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalVoters;
            i++
        ) {
            address newVoter = address(uint160(i));
            vm.prank(newVoter);
            votingInstance.vote(candidateOne);
        }

        vm.expectRevert(Voting.Voting__TimeHasNotElapsed.selector);
        votingInstance.selectWinner();
    }

    function testCanGetCandidates__createVotingSession() public {
        votingInstance.createVotingSession(candidates, interval);
        address[] memory candidare = votingInstance.getCandidates();
        console.log(candidare[1], candidare[0]);
    }

    function testCannotVoteAfterTimeHasElapsed__createVotingSession() public {
        //arrange
        votingInstance.createVotingSession(candidates, interval);
        vm.prank(USER);
        //act
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        vm.expectRevert(Voting.Voting__TimeHasElapsed.selector);
        votingInstance.vote(candidateOne);
        //assert
        assertEq(votingInstance.getVoteStatus(USER), false);
        assert(votingInstance.checkVotes(candidateOne) == 0);
        console.log(
            votingInstance.getVoteStatus(USER),
            votingInstance.checkVotes(candidateOne)
        );
    }

    function testCanOnlyVoteForRegisteredCandidates() public {
        //arrange
        votingInstance.createVotingSession(candidates, interval);
        vm.prank(USER);
        //act
        vm.expectRevert(Voting.Voting__InvalidCandidate.selector);
        votingInstance.vote(USER);
    }
}
