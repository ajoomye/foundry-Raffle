//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {Raffle} from "src/Raffle.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RaffleTest is Test, CodeConstants{

    Raffle public raffle;
    HelperConfig public helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId; 
    uint32 callbackGasLimit;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    //Emitted Events
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.deployContract();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config._entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        subscriptionId = config.subscriptionId;
        callbackGasLimit = config.callbackGasLimit; 

        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
    }

    function testRaffleInitOpenstate() public {
        assertEq(raffle.getRaffleState() == Raffle.RaffleState.OPEN, true);
    }

    //test enterRaffle
    function testenterRaffle() public {
        //Arrange 
        vm.prank(PLAYER);

        //Act/Assert
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
        raffle.enterRaffle();     
    }

    function testRaffleRecordsPlayerswhenEntered() public {
        //Arrange 
        vm.prank(PLAYER);

        //Act
        raffle.enterRaffle{value: entranceFee}();

        //Assert
        address playerRecorded = raffle.getPlayers(0);
        assertEq(playerRecorded, PLAYER);
    }

    function testEnteringEmitsEvent() public {
        //Arrange 
        vm.prank(PLAYER);

        //Act
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);
        
        //Assert
        raffle.enterRaffle{value: entranceFee}();
    }

    function testdontallowRaffleEntryWhenNotOpen() public {
        //Arrange 
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        //Act/Assert
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
        raffle.enterRaffle();   
    }

    function testcheckUpkeepifnobalance() public {
        //Arrange 
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        //Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        //assert
        assert(!upkeepNeeded);

    }

    modifier raffleEntered(){
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testcheckupkeepReturnsFalseifnotopen() public {
        //Arrange 
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        //Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        //Assert
        assert(!upkeepNeeded);
    }

    //////////////////////////
    //TEST PERFORM UPKEEP
    //////////////////////////

    function testPerformUpkeepcanonlyrunifcheckupkeepreturnsTrue() public {
        //Arrange 
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        //Act/Assert
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertsifCheckUpkeepisFalse() public {
        //Arrange 
        uint256 currentBalance = 0;
        uint256 numplayers = 0;
        Raffle.RaffleState rState = raffle.getRaffleState();

        //Act/Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector, 
                currentBalance, numplayers));
        raffle.performUpkeep("");
    }

    function testPerformUpkeepChangesRaffleState() public raffleEntered {
        //Arrange 
        

        //Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        //Assert
        Raffle.RaffleState rState = raffle.getRaffleState();
        assert(uint256(requestId) > 0);
        assert(uint256(rState) == 1);
        
    }
    
    modifier skipFork() {
        if (block.chainid != LOCAL_CHAINID) {
            return;
        }
        _;
    }


    //////////////////////////
    // TEST fULFILL RANDOMWORDS
    //////////////////////////

    function testfullfillRandomWordscalledafterperformUpkeep(uint256 randomRequestId) public raffleEntered skipFork {
        //Arrange 
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
    }

    function testfullfillrandomwordspickswinnerandsendsmoney() public raffleEntered skipFork {
        //Arrange 
        uint256 additionalEntrants = 3;
        uint256 startingIndex = 1;

        for (uint256 i = 0; i < startingIndex + additionalEntrants; i++) {
            address newPlayer = address(uint160(i));
            hoax(newPlayer, 1 ether);
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 startingTimestamp = raffle.getLasttimestamp();

        //Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        //Assert
        address winner = raffle.getRecentWinner();
        assertEq(raffle.getRaffleState() == Raffle.RaffleState.OPEN, true);
        uint256 winnerBalance = winner.balance;
        uint256 endingTimestamp = raffle.getLasttimestamp();
        uint256 prize = entranceFee * (additionalEntrants + 1);

        assert(endingTimestamp > startingTimestamp);

    }





}