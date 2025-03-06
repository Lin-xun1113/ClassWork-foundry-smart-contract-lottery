// CEI design rule: 1. Checks 2. Effects 3. Interactions

// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
/**
 * @title A sample Raffle Contract
 * @author Linxun
 * @notice This contract is for creating a sample raffle contract
 * @dev This implements the Chainlink VRF Version 2
 */

 contract Raffle is VRFConsumerBaseV2{
    error Raffle_NotEnoughEthSent();
    error Raffle__TransferFailed();
    error Raffle__NotOpen();
    error Raffle__UpkeepNotNeeded(uint256 currentBalance, uint256 numPlayers, uint256 raffleState);
    
    /** Type declarations */
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /** State Variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    uint32 private immutable i_callbackGasLimit;
    uint64 private immutable i_subscriptionId;
    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval;
    uint256 private s_lastTimeStamp;
    uint256 private immutable i_deployerKey;    
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    address private s_recentWinner;
    address payable[]  private s_players;
    RaffleState private s_raffleState;

    bytes32 private  immutable i_gasLane;



    /** Event */
    event EnteredRaffle(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);


    constructor(
        uint64 subscriptionId,
        bytes32 gasLane, // keyHash
        uint256 interval,
        uint256 entranceFee,
        uint32 callbackGasLimit,
        address vrfCoordinatorV2,
        uint256 deployerKey
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_gasLane = gasLane;
        i_interval = interval;
        i_subscriptionId = subscriptionId;
        i_entranceFee = entranceFee;
        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
        i_callbackGasLimit = callbackGasLimit;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_deployerKey = deployerKey;
        // uint256 balance = address(this).balance;
        // if (balance > 0) {
        //     payable(msg.sender).transfer(balance);
        // }
    }

    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            revert Raffle_NotEnoughEthSent();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__NotOpen();
        }
        s_players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    // 1. Get a random number
    // 2. Use the random number to get the winner
    // 3. Be automaticallt called

    // function pickupWinner() external returns (address) {
    //     if ((block.timestamp - s_lastTimeStamp) < i_interval) {
    //         revert;
    //     }

    //     // 1. Request the RNG
    //     // 2. Get the random number
    //     uint256 requestId = i_vrfCoordinator.requestRandomWords(
    //         VRFV2PlusClient.RandomWordsRequest({
    //             i_gasLane,
    //             i_subscriptionId,
    //             REQUEST_CONFIRMATIONS,
    //             i_callbackGasLimit,
    //             NUM_WORDS,
    //             extraArgs: VRFV2PlusClient._argsToBytes(
    //                 VRFV2PlusClient.ExtraArgsV1({
    //                     nativePayment: enableNativePayment
    //                 })
    //             )
    //         })
    //     );
    // }

    /**
     * @dev This is the function that the Chainlink Keeper nodes call
     * they look for `upkeepNeeded` to return True.
     * the following should be true for this to return true:
     * 1. The time interval has passed between raffle runs.
     * 2. The lottery is open.
     * 3. The contract has ETH.
     * 4. Implicity, your subscription is funded with LINK.
     */
    function checkUpkeep(bytes memory /* checkData */ )
        public
        view
        returns (bool upkeepNeeded, bytes memory /* performData */ )
    {
        bool isOpen = RaffleState.OPEN == s_raffleState;
        bool timePassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
        bool hasPlayers = s_players.length > 0;
        bool hasBalance = address(this).balance > 0;
        upkeepNeeded = (timePassed && isOpen && hasBalance && hasPlayers);
        return (upkeepNeeded, "0x0"); // can we comment this out?
    }

    /**
     * @dev Once `checkUpkeep` is returning `true`, this function is called
     * and it kicks off a Chainlink VRF call to get a random winner.
     */
    function performUpkeep(bytes calldata /* performData */ ) external {
        (bool upkeepNeeded,) = checkUpkeep("");
        // require(upkeepNeeded, "Upkeep not needed");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }

        s_raffleState = RaffleState.CALCULATING;

        // Will revert if subscription is not set and funded.
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        // Quiz... is this redundant?
        emit RequestedRaffleWinner(requestId);
    }


    /**
     * @dev This is the function that Chainlink VRF node
     * calls to send the money to the random winner.
     */
    function fulfillRandomWords(uint256, /* requestId */ uint256[] memory randomWords) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        s_players = new address payable[](0);
        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
        emit WinnerPicked(recentWinner);
        (bool success,) = recentWinner.call{value: address(this).balance}("");
        // require(success, "Transfer failed");
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }


    /** Getter functions */
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }
    function getPlayer(uint256 indexOfPlayer) external view returns (address) {
        return s_players[indexOfPlayer];
    }
    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }
    function getLengthOfPlayers() external view returns (uint256) {
        return s_players.length;
    }
    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }
 }