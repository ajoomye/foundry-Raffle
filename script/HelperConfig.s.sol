//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";

abstract contract CodeConstants {
    uint256 public constant BASE_SEPOLIA_CHAINID = 84532;
    uint256 public constant LOCAL_CHAINID = 31337;
    uint256 public constant SEPOLIA_CHAINID = 11155111;

    //Vrf Mock Values
    uint96 public constant MOCKVRF_BASE_FEE = 0.25 ether;
    uint96 public constant MOCKVRF_GAS_PRICE = 1e9;
    int256 public constant MOCKVRF_WEI_PER_UNIT_LINK = 4e15;
}

contract HelperConfig is CodeConstants, Script {

     error HelperConfig__InvalidChainId(uint256 chainId);

    struct NetworkConfig {
        uint256 _entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint256 subscriptionId; 
        uint32 callbackGasLimit;
        address link;
        address account;
    }

    NetworkConfig public localnetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[BASE_SEPOLIA_CHAINID] = getBaseSepoliaEthConfig();
        networkConfigs[SEPOLIA_CHAINID] = getSepoliaEthConfig();
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigbyChainId(block.chainid);
    }

    function getConfigbyChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (networkConfigs[chainId].vrfCoordinator != address(0)) {
            return networkConfigs[chainId];
        } else if (chainId == LOCAL_CHAINID) {
            return getorCreateAnvilEthConfig();
        } else {
            revert HelperConfig__InvalidChainId(chainId);
        }

    }

    function getBaseSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            _entranceFee: 0.01 ether,
            interval: 30, //30 seconds
            vrfCoordinator: 0x5C210eF41CD1a72de73bF76eC39637bB0d3d7BEE,
            gasLane: 0x9e1344a1247c8a1785d0a4681a27152bffdb43666ae5bf7d14d24a5efd44bf71,
            subscriptionId: 9578041351816963054557748489128963897322892865359714005457651948860136469217,
            callbackGasLimit: 500000,
            link: 0xE4aB69C077896252FAFBD49EFD26B5D171A32410,
            account: 0xcbdc15ad58a24723e7764be613BF28cacC3A66D6
        });
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            _entranceFee: 0.01 ether,
            interval: 30, //30 seconds
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subscriptionId: 14239879877243233672861881842426030129083092608030978100158876738497302474468,
            callbackGasLimit: 500000,
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            account: 0xcbdc15ad58a24723e7764be613BF28cacC3A66D6
            
        });
    }

    function getorCreateAnvilEthConfig () public returns (NetworkConfig memory) {
        //Check if active NetworkConfig exists
        if (localnetworkConfig.vrfCoordinator != address(0)) {
            return localnetworkConfig;
        } 

        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinatorMock = new VRFCoordinatorV2_5Mock(MOCKVRF_BASE_FEE, MOCKVRF_GAS_PRICE, MOCKVRF_WEI_PER_UNIT_LINK); 
        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();

        localnetworkConfig = NetworkConfig({
            _entranceFee: 0.01 ether,
            interval: 30, //30 seconds
            vrfCoordinator: address(vrfCoordinatorMock),
            gasLane: 0x9e1344a1247c8a1785d0a4681a27152bffdb43666ae5bf7d14d24a5efd44bf71,
            subscriptionId: 0,
            callbackGasLimit: 500000,
            link: address(linkToken),
            account: 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
        });

        return localnetworkConfig;
        

    }


}