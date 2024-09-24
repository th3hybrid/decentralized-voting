// SPDX-License-Identifier: MIT

pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {Voting} from "src/Voting.sol";
import {DeployVoting} from "script/DeployVoting.s.sol";

contract VotingTest is Test {
    Voting voting;
    DeployVoting deployer;

    address public USER = makeAddr("user");
    address public candidateOne = 0xdD870fA1b7C4700F2BD7f44238821C26f7392148;
    address public candidateTwo = 0x583031D1113aD414F02576BD6afaBfb302140225;
    uint256 private constant INTERVAL = 360;

    function setUp() public {
        deployer = new DeployVoting();
        voting = deployer.run();
    }

    function testCanVote() public {
        //arrange
        vm.prank(USER);
        //act
        voting.vote(candidateOne);
        //assert
        assertEq(voting.getVoteStatus(USER), true);
        assert(voting.checkVotes(candidateOne) == 1);
    }

    function testCanOnlyVoteOnce() public {
        //arrange
        vm.prank(USER);
        //act/assert
        voting.vote(candidateOne);
        vm.expectRevert(Voting.Voting__CanOnlyVoteOnce.selector);
        vm.prank(USER);
        voting.vote(candidateTwo);
    }

    function testCanSelectWinner() public {
        //arrange
        uint256 additionalVoters = 2;
        uint256 startingIndex;
        vm.prank(USER);
        //act
        voting.vote(candidateTwo);

        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalVoters;
            i++
        ) {
            address newVoter = address(uint160(i));
            vm.prank(newVoter);
            voting.vote(candidateOne);
        }

        vm.warp(block.timestamp + INTERVAL + 1);
        vm.roll(block.number + 1);

        address winner = voting.selectWinner();
        //assert
        assert(winner == candidateOne);
    }

    function testCanOnlySelectWinnerWhenTimeHasElapsed() public {
        //arrange
        uint256 additionalVoters = 2;
        uint256 startingIndex;
        vm.prank(USER);
        //act
        voting.vote(candidateTwo);

        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalVoters;
            i++
        ) {
            address newVoter = address(uint160(i));
            vm.prank(newVoter);
            voting.vote(candidateOne);
        }

        vm.expectRevert(Voting.Voting__TimeHasNotElapsed.selector);
        voting.selectWinner();
    }

    function testCannotVoteAfterTimeHasElapsed() public {
        //arrange
        vm.prank(USER);
        //act
        vm.warp(block.timestamp + INTERVAL + 1);
        vm.roll(block.number + 1);
        vm.expectRevert(Voting.Voting__TimeHasElapsed.selector);
        voting.vote(candidateOne);
        //assert
        assertEq(voting.getVoteStatus(USER), false);
        assert(voting.checkVotes(candidateOne) == 0);
        console.log(
            voting.getVoteStatus(USER),
            voting.checkVotes(candidateOne)
        );
    }

    function testCanOnlyVoteForRegisteredCandidates() public {
        //arrange
        vm.prank(USER);
        //act
        vm.expectRevert(Voting.Voting__InvalidCandidate.selector);
        voting.vote(USER);
    }
}
