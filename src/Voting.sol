// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

contract Voting is VRFConsumerBaseV2Plus {
    error Voting__CanOnlyVoteOnce();
    error Voting__InvalidCandidate();
    error Voting__TimeHasElapsed();
    error Voting__TimeHasNotElapsed();
    error Voting__NoTiedCandidates();

    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    mapping(address => uint256) private s_candidateVotes;
    mapping(address => bool) private s_hasVoted;
    address[] private s_candidates;
    uint256 private s_votingStartTime;
    uint256 private immutable i_interval;
    address private s_voteWinner;
    address[] private s_tiedCandidates;
    uint256 private s_tieCount;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;

    event RequestedVoteWinner(uint256 indexed requestId);

    constructor(
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit,
        address[] memory _candidates,
        uint256 _interval
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        s_candidates = _candidates;
        s_votingStartTime = block.timestamp;
        i_interval = _interval;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
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

    function vote(
        address _candidate,
        address _voter
    ) public isCandidate(_candidate) {
        if (s_hasVoted[_voter]) {
            revert Voting__CanOnlyVoteOnce();
        }

        bool timeHasElapsed;
        (, timeHasElapsed) = checkTimeLeft();
        if (timeHasElapsed) {
            revert Voting__TimeHasElapsed();
        }

        s_hasVoted[_voter] = true;
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

    function selectWinner() public returns (address, address[] memory) {
        bool timeHasElapsed;
        (, timeHasElapsed) = checkTimeLeft();
        if (!timeHasElapsed) {
            revert Voting__TimeHasNotElapsed();
        }

        uint256 highestVoteCount = 0;
        address winner;
        delete s_tiedCandidates; // Reset tied candidates for a new session
        s_tieCount = 0;

        // First pass: Find the highest vote count and track tied candidates
        for (uint256 i = 0; i < s_candidates.length; i++) {
            address candidate = s_candidates[i];
            uint256 candidateVotes = s_candidateVotes[candidate];

            if (candidateVotes > highestVoteCount) {
                // New highest vote found
                highestVoteCount = candidateVotes;
                winner = candidate;

                // Clear any previous ties
                delete s_tiedCandidates;
                s_tieCount = 0;
            } else if (candidateVotes == highestVoteCount) {
                // Tie detected, add the candidate to the tied list
                if (s_tieCount == 0) {
                    // If this is the first tie, add the current winner to the list
                    s_tiedCandidates.push(winner);
                    s_tieCount++;
                }
                s_tiedCandidates.push(candidate);
                s_tieCount++;
            }
        }

        if (s_tieCount > 0) {
            // If there's a tie, request randomness to break it
            requestRandomWords();
        } else {
            // No tie, declare the winner
            s_voteWinner = winner;
        }
        return (s_voteWinner, s_tiedCandidates);
    }

    function requestRandomWords() internal {
        //Getting random mumber from chainlink vrf
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient
            .RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            });
        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
        emit RequestedVoteWinner(requestId);
    }

    //CEI: CHECKS,EFFECTS AND INTERACTIONS PATTERN
    function fulfillRandomWords(
        uint256 /*requestId*/,
        uint256[] calldata randomWords
    ) internal override {
        //Checks(basically conditionals or require)
        if (s_tiedCandidates.length == 0) {
            revert Voting__NoTiedCandidates();
        }

        //Effects (Internal Contract State)
        uint256 indexOfWinner = randomWords[0] % s_tiedCandidates.length;
        address finalWinner = s_tiedCandidates[indexOfWinner];
        s_voteWinner = finalWinner;

        //Interactions (External contract Interactions)
    }

    function getCandidates() public view returns (address[] memory) {
        return s_candidates;
    }

    function getVoteStatus(address _voter) public view returns (bool) {
        return s_hasVoted[_voter];
    }

    function getWinner() public view returns (address) {
        return s_voteWinner;
    }
}
