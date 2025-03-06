// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2Mock.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        uint64 subscriptionId;
        bytes32 gasLane; // keyHash
        uint256 interval;
        uint256 entranceFee;
        uint32 callbackGasLimit;
        address vrfCoordinatorV2;
        uint256 deployerKey;
    }

    NetworkConfig public activeNetworkConfig;
    uint256 public constant DEFAULT_ANVIL_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        }else{
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            subscriptionId: 0, // Upadate this with our subscription ID
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            interval: 30,
            entranceFee: 0.01 ether,
            callbackGasLimit: 500000,
            vrfCoordinatorV2: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.vrfCoordinatorV2 != address(0)) {
            return activeNetworkConfig;
        }

        uint96 baseFee = 0.25 ether;
        uint96 gasPriceLink = 1e9;

        vm.startBroadcast();
        VRFCoordinatorV2Mock vrfCoordinatorMock = new VRFCoordinatorV2Mock(
            baseFee,
            gasPriceLink
        );
        // Create a new subscription
        uint64 subId = vrfCoordinatorMock.createSubscription();
        // Fund the subscription
        vrfCoordinatorMock.fundSubscription(subId, 1 * 10**18);
        vm.stopBroadcast();

        return NetworkConfig({
            subscriptionId: subId, // Update this with our subscription ID
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            interval: 30,
            entranceFee: 0.01 ether,
            callbackGasLimit: 500000,
            vrfCoordinatorV2: address(vrfCoordinatorMock),
            deployerKey: DEFAULT_ANVIL_KEY
        });
    }
}
