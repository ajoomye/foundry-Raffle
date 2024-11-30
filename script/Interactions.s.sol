//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {DevOpsTools} from "../lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script, CodeConstants {
    
    function CreateSubscriptionUsingConfig() public returns(uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        address account = helperConfig.getConfig().account;
        (uint256 subId, ) = createSubscription(vrfCoordinator, account);
        return (subId, vrfCoordinator);

    }

    function createSubscription(address vrfCoordinator, address account) public returns(uint256, address){
        //create subscription
        console.log("Creating Subscription on chain id: ", block.chainid);

        vm.startBroadcast(account);
        //Getting the subscription id
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();

        console.log("Subscription Id: ", subId);    
        console.log("Add sub Id to your HelperConfig");

        return (subId, vrfCoordinator);

    }

    function run() public  {
        CreateSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script, CodeConstants {

    uint256 public constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public {
        //FundSubscription
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subId = helperConfig.getConfig().subscriptionId;
        address linkToken = helperConfig.getConfig().link;
        address account = helperConfig.getConfig().account;
        fundSubscription(vrfCoordinator, subId, linkToken, account);

        
    }

    function fundSubscription(address vrfCoordinator, uint256 subId, address linkToken, address account) public {
        console.log("Funding Subscription on chain id: ", block.chainid);

        if (block.chainid == LOCAL_CHAINID) {
            vm.startBroadcast(account);
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subId, FUND_AMOUNT * 100000);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(account);
            LinkToken(linkToken).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subId));
            vm.stopBroadcast();
        }
        

        console.log("Subscription Funded with: ", FUND_AMOUNT);
    }

    function run() public  {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumerusingConfig(address mostRecentlyDeployed) public {
        //Add Consumer
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subId = helperConfig.getConfig().subscriptionId;
        address account = helperConfig.getConfig().account;
        addConsumer(mostRecentlyDeployed, vrfCoordinator, subId, account);
    }

    function addConsumer(address contracttoAddvrf, address vrfCoordinator, uint256 subId, address account) public {
        console.log("Adding Consumer on chain id: ", block.chainid);

        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subId, contracttoAddvrf);
        vm.stopBroadcast();
    }

    function run() public  {
        address mostRecentRaffle = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerusingConfig(mostRecentRaffle);
    }
}