//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

/**
    * @title Raffle
    * @author Abdurraheem Joomye
    * @dev A contract for a raffle using Solidity and Chainlink VRFv2.5
    * @notice This contract is for a simple raffle 
 */

contract Raffle is VRFConsumerBaseV2Plus {

    //Errors
    error Raffle__NotEnoughEthSent();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(uint256 balance, uint256 players);

    //Type Declarations
    enum RaffleState {OPEN, CALCULATING}

    //State Variables
    uint256 private immutable i_entranceFee;
    address payable[] private s_players;
    // @dev interval is the time between raffles
    uint256 private immutable i_interval;
    uint256 private s_lastTimeStamp;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint16 private constant requestConfirmations = 3;
    uint32 private immutable i_callbackGasLimit;
    uint32 private constant numWords =  1;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    //Events
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);
    

    constructor(uint256 _entranceFee, uint256 interval, 
    address vrfCoordinator, bytes32 gasLane, uint256 subscriptionId, uint32 callbackGasLimit) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = _entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;

    }

    function enterRaffle() external payable {
        //payable to get the value of the transaction
        // Users enter the raffle, pay entrance
        // require(msg.value >= i_entranceFee, "You must pay the minimum entrance fee to enter the raffle");
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEthSent();
        }

        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }

        s_players.push(payable(msg.sender));

        emit RaffleEntered(msg.sender);
    }

    function checkUpkeep(bytes memory) public view returns (bool upkeepNeeded, bytes memory) {
        //time internval has passed
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;
        return (upkeepNeeded, "");
    }

    // 1. Get a random number
    // 2. Pick a winner using random number
    // 3. Pick winner automatically
    function performUpkeep(bytes calldata /* performData */) external {
        // Pick a winner
        //check if upkeep is needed
        (bool upkeepNeeded, ) = checkUpkeep("");
        if(!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length);
        }
        s_raffleState = RaffleState.CALCULATING;

        // Get a random number
        //1. Request a random number from Chainlink VRF

        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: i_callbackGasLimit,
                numWords: numWords,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })); 

        emit RequestedRaffleWinner(requestId);

    }


    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) 
    internal virtual override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentwinner = s_players[indexOfWinner];
        s_recentWinner = recentwinner;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit WinnerPicked(recentwinner);


        (bool success, ) = recentwinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
            }

        
    }



    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayers(uint256 indexOfplayer) external view returns (address) {
        return s_players[indexOfplayer];
    }

    function getLasttimestamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }

}