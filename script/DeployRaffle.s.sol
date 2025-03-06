// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2Mock.sol";


contract DeployRaffle is Script {
    function run() external returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (       uint64 subscriptionId,
        bytes32 gasLane, // keyHash
        uint256 interval,
        uint256 entranceFee,
        uint32 callbackGasLimit,
        address vrfCoordinatorV2,
        uint256 deployerKey) = helperConfig.activeNetworkConfig();
        
        vm.startBroadcast();
        Raffle raffle = new Raffle(
            subscriptionId,
            gasLane,
            interval,
            entranceFee,
            callbackGasLimit,
            vrfCoordinatorV2,
            deployerKey
        );
        
        // If the network is local, add the raffle as a consumer of the VRF Coordinator
        if (block.chainid == 31337) {
            VRFCoordinatorV2Mock vrfCoordinatorMock = VRFCoordinatorV2Mock(vrfCoordinatorV2);
            vrfCoordinatorMock.addConsumer(subscriptionId, address(raffle));
        }
        
        vm.stopBroadcast();
        return (raffle, helperConfig);
    }
}