// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./TokenContract.sol";

contract ContestTaskManager is ReentrancyGuard, Ownable {
    using Counters for Counters.Counter;

    uint256 private constant INTEREST_RATE = 5; // 5% annual interest rate
    uint256 private constant SECONDS_PER_YEAR = 365 * 24 * 60 * 60;

    TokenManager public tokenManager;

    struct Participant {
        uint256 depositAmount;
        uint256 depositTimestamp;
        uint256 lastInterestClaimTime;
        uint256 votesReceived;
        bool hasVoted;
        bool hasFinished;
    }

    struct ContestDetails {
        string title;
        string description;
        string goals;
        uint256 totalDeposited;
        uint256 totalInterestGenerated;
        uint256 participantsCount;
        uint256 votingDeadline;
        bool active;
    }

    Counters.Counter private _contestCounter;

    mapping(uint256 => ContestDetails) public contests;
    mapping(uint256 => mapping(address => Participant)) public contestParticipants;

    event ContestCreated(uint256 indexed contestId, string title, uint256 votingDeadline);
    event ParticipantJoined(uint256 indexed contestId, address indexed participant, uint256 amount);
    event InterestClaimed(address indexed participant, uint256 contestId, uint256 interestAmount);
    event Voted(uint256 indexed contestId, address indexed voter, address indexed nominee);
    event WinnerAnnounced(uint256 indexed contestId, address winner);

    constructor(address _tokenManager) Ownable(msg.sender) {
        tokenManager = TokenManager(_tokenManager);
    }

    function createContest(
        string memory _title,
        string memory _description,
        string memory _goals,
        uint256 _votingDuration
    ) external onlyOwner returns (uint256) {
        _contestCounter.increment();
        uint256 contestId = _contestCounter.current();

        contests[contestId] = ContestDetails({
            title: _title,
            description: _description,
            goals: _goals,
            totalDeposited: 0,
            totalInterestGenerated: 0,
            participantsCount: 0,
            votingDeadline: block.timestamp + _votingDuration,
            active: true
        });

        emit ContestCreated(contestId, _title, contests[contestId].votingDeadline);
        return contestId;
    }

    function deposit(uint256 contestId) external payable nonReentrant {
        require(msg.value > 0, "Deposit amount must be greater than 0");
        require(contests[contestId].active, "Contest is not active");

        Participant storage participant = contestParticipants[contestId][msg.sender];
        require(!participant.hasFinished, "Participant already finished");

        if (participant.depositAmount == 0) {
            contests[contestId].participantsCount++;
            participant.lastInterestClaimTime = block.timestamp;
        } else {
            _claimInterest(contestId, msg.sender); // Claim interest before adding a new deposit
        }

        participant.depositAmount += msg.value;
        participant.depositTimestamp = block.timestamp;

        contests[contestId].totalDeposited += msg.value;

        emit ParticipantJoined(contestId, msg.sender, msg.value);
    }

    function claimInterest(uint256 contestId) external nonReentrant {
        _claimInterest(contestId, msg.sender);
    }

    function _claimInterest(uint256 contestId, address participantAddress) internal {
        Participant storage participant = contestParticipants[contestId][participantAddress];
        require(participant.depositAmount > 0, "No deposit found");

        uint256 currentTime = block.timestamp;
        uint256 elapsedTime = currentTime - participant.lastInterestClaimTime;

        uint256 annualInterest = (participant.depositAmount * INTEREST_RATE) / 100;
        uint256 accruedInterest = (annualInterest * elapsedTime) / SECONDS_PER_YEAR;

        participant.lastInterestClaimTime = currentTime;

        if (accruedInterest > 0) {
            tokenManager.mint(participantAddress, accruedInterest);
            contests[contestId].totalInterestGenerated += accruedInterest;
            emit InterestClaimed(participantAddress, contestId, accruedInterest);
        }
    }

    function vote(uint256 contestId, address nominee) external nonReentrant {
        require(block.timestamp <= contests[contestId].votingDeadline, "Voting period has ended");
        require(contests[contestId].active, "Contest is not active");

        Participant storage voter = contestParticipants[contestId][msg.sender];
        Participant storage nomineeParticipant = contestParticipants[contestId][nominee];

        require(voter.depositAmount > 0, "You must be a participant to vote");
        require(!voter.hasVoted, "You have already voted");
        require(nomineeParticipant.depositAmount > 0, "Nominee must be a participant");

        voter.hasVoted = true;
        nomineeParticipant.votesReceived++;

        emit Voted(contestId, msg.sender, nominee);
    }

    function getWinner(uint256 contestId) external view returns (address winner) {
        require(block.timestamp > contests[contestId].votingDeadline, "Voting period is not over");
        require(contests[contestId].active, "Contest is still active");

        uint256 maxVotes = 0;
        address currentWinner;

        for (uint256 i = 0; i < contests[contestId].participantsCount; i++) {
            Participant storage participant = contestParticipants[contestId][currentWinner];
            if (participant.votesReceived > maxVotes) {
                maxVotes = participant.votesReceived;
                currentWinner = currentWinner;
            }
        }

        return currentWinner;
    }

    function endContest(uint256 contestId) external onlyOwner {
        require(contests[contestId].active, "Contest is already inactive");
        contests[contestId].active = false;

        address winner = this.getWinner(contestId);
        emit WinnerAnnounced(contestId, winner);
    }

    function getAccruedInterest(uint256 contestId, address participantAddress) external view returns (uint256) {
        Participant storage participant = contestParticipants[contestId][participantAddress];
        if (participant.depositAmount == 0) return 0;

        uint256 elapsedTime = block.timestamp - participant.lastInterestClaimTime;
        uint256 annualInterest = (participant.depositAmount * INTEREST_RATE) / 100;

        return (annualInterest * elapsedTime) / SECONDS_PER_YEAR;
    }

    receive() external payable {}
}
