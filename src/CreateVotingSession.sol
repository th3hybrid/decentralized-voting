// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {DeployVoting} from "script/DeployVoting.s.sol";
import {Voting} from "src/Voting.sol";

contract CreateVotingSession {
    error CreateVotingSession__VoteSessionStillActive();
    error CreateVotingSession__OnlyModeratorCanCreateVotingSession();

    Voting public currentVotingSession;
    DeployVoting deployer;
    uint256 public s_votingSessionId;
    mapping(uint256 => Voting) private s_voteSessions;

    constructor() {
        s_votingSessionId = 0;
    }

    function createVotingSession(
        address[] memory _candidates,
        uint256 _interval
    ) public {
        if (s_votingSessionId > 0) {
            (, bool timeHasElapsed) = s_voteSessions[s_votingSessionId]
                .checkTimeLeft();
            if (!timeHasElapsed) {
                revert CreateVotingSession__VoteSessionStillActive();
            }
        }

        s_votingSessionId++;
        deployer = new DeployVoting();
        (currentVotingSession, ) = deployer.run(_candidates, _interval);
        s_voteSessions[s_votingSessionId] = currentVotingSession;
    }

    function vote(address _candidate) public {
        currentVotingSession.vote(_candidate, msg.sender);
    }

    function checkVotes(address _candidate) public view returns (uint256) {
        uint256 candidateVotes = currentVotingSession.checkVotes(_candidate);
        return candidateVotes;
    }

    function checkTimeLeft() public view returns (uint256, bool) {
        (uint256 timeLeft, bool isTimeLeft) = currentVotingSession
            .checkTimeLeft();
        return (timeLeft, isTimeLeft);
    }

    function selectWinner() public {
        currentVotingSession.selectWinner();
    }

    function getCandidates() public view returns (address[] memory) {
        return currentVotingSession.getCandidates();
    }

    function getVoteStatus(address _voter) public view returns (bool) {
        return currentVotingSession.getVoteStatus(_voter);
    }

    function getWinner() public view returns (address) {
        return currentVotingSession.getWinner();
    }

    function getVotingSessionId() public view returns (uint256) {
        return s_votingSessionId;
    }

    function getVoteSession(uint256 _id) public view returns (Voting) {
        return s_voteSessions[_id];
    }
}
