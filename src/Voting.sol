// SPDX-License-Identifier: MIT

pragma solidity ^0.8.25;

contract Voting {
    error Voting__CanOnlyVoteOnce();
    error Voting__InvalidCandidate();
    error Voting__TimeHasElapsed();
    error Voting__TimeHasNotElapsed();

    mapping(address => uint256) private s_candidateVotes;
    mapping(address => bool) private s_hasVoted;
    address[] private s_candidates;
    uint256 private s_votingStartTime;
    uint256 private immutable i_interval;

    constructor(address[] memory _candidates, uint256 _interval) {
        s_candidates = _candidates;
        s_votingStartTime = block.timestamp;
        i_interval = _interval;
    }

    modifier isCandidate(address _candidate) {
        bool isValidCandidate = false;
        for (uint256 i = 0; i < s_candidates.length; i++) {
            if (_candidate == s_candidates[i]) {
                isValidCandidate = true;
                break;
            }
        }

        if (!isValidCandidate) {
            revert Voting__InvalidCandidate();
        }
        _;
    }

    function vote(address _candidate) public isCandidate(_candidate) {
        if (s_hasVoted[msg.sender]) {
            revert Voting__CanOnlyVoteOnce();
        }

        bool timeHasElapsed;
        (, timeHasElapsed) = checkTimeLeft();
        if (timeHasElapsed) {
            revert Voting__TimeHasElapsed();
        }

        s_hasVoted[msg.sender] = true;
        s_candidateVotes[_candidate] += 1;
    }

    function checkVotes(
        address _candidate
    ) public view isCandidate(_candidate) returns (uint256) {
        return s_candidateVotes[_candidate];
    }

    function checkTimeLeft() public view returns (uint256, bool) {
        if (block.timestamp >= s_votingStartTime + i_interval) {
            return (0, true);
        } else {
            return ((s_votingStartTime + i_interval) - block.timestamp, false);
        }
    }

    function selectWinner() public view returns (address) {
        bool timeHasElapsed;
        (, timeHasElapsed) = checkTimeLeft();
        if (!timeHasElapsed) {
            revert Voting__TimeHasNotElapsed();
        }
        address highestVotes;
        for (uint256 i = 0; i < s_candidates.length; i++) {
            if (
                s_candidateVotes[s_candidates[i]] >
                s_candidateVotes[highestVotes]
            ) {
                highestVotes = s_candidates[i];
            }
        }

        return highestVotes;
    }

    function getCandidates() public view returns (address[] memory) {
        return s_candidates;
    }

    function getVoteStatus(address _voter) public view returns (bool) {
        return s_hasVoted[_voter];
    }
}
