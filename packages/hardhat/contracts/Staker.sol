// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "hardhat/console.sol";
import "./ExampleExternalContract.sol";

contract Staker {

    ExampleExternalContract public exampleExternalContract;

    mapping(address => uint256) public balances;
    mapping(address => uint256) public depositTimestamps;

    uint256 public constant rewardRatePerSecond = 0.1 ether;
    uint256 public withdrawalDeadline = block.timestamp + 120 seconds;
    uint256 public claimDeadline = block.timestamp + 240 seconds;
    uint256 public currentBlock = 0;

    event Stake(address indexed sender, uint256 amount);
    event Received(address, uint);
    event Execute(address indexed sender, uint256 amount);

    constructor(address exampleExternalContractAddress) public {
        exampleExternalContract = ExampleExternalContract(exampleExternalContractAddress);
    }

    // Collect funds in a payable `stake()` function and track individual `balances` with a mapping:
    //  ( make sure to add a `Stake(address,uint256)` event and emit it for the frontend <List/> display )
    // Stake function for a user to stake ETH in our contract
    function stake() public payable withdrawalDeadlineReached(false) claimDeadlineReached(false) {
        balances[msg.sender] = balances[msg.sender] + msg.value;
        depositTimestamps[msg.sender] = block.timestamp;
        emit Stake(msg.sender, msg.value);
    }


    // After some `deadline` allow anyone to call an `execute()` function
    //  It should either call `exampleExternalContract.complete{value: address(this).balance}()` to send all the value
    /*
       Allows any user to repatriate "unproductive" funds that are left in the staking contract
       past the defined withdrawal period
     */
    function execute() public claimDeadlineReached(true) notCompleted {
        uint256 contractBalance = address(this).balance;
        exampleExternalContract.complete{value: address(this).balance}();
    }


    // if the `threshold` was not met, allow everyone to call a `withdraw()` function

    // Add a `withdraw()` function to let users withdraw their balance
    /*
       Withdraw function for a user to remove their staked ETH inclusive
       of both the principle balance and any accrued interest
     */
    function withdraw() public withdrawalDeadlineReached(true) claimDeadlineReached(false) notCompleted{
        require(balances[msg.sender] > 0, "You have no balance to withdraw!");
        uint256 individualBalance = balances[msg.sender];
        uint256 indBalanceRewards = individualBalance + ((block.timestamp-depositTimestamps[msg.sender])*rewardRatePerSecond);
        balances[msg.sender] = 0;

        // Transfer all ETH via call! (not transfer) cc: https://solidity-by-example.org/sending-ether
        (bool sent, bytes memory data) = msg.sender.call{value: indBalanceRewards}("");
        require(sent, "RIP; withdrawal failed :( ");
    }

    // Add a `timeLeft()` view function that returns the time left before the deadline for the frontend
    function withdrawalTimeLeft() public view returns (uint256 withdrawalTimeLeft) {
        if( block.timestamp >= withdrawalDeadline) {
            return (0);
        } else {
            return (withdrawalDeadline - block.timestamp);
        }
    }

    // Add the `receive()` special function that receives eth and calls stake()
    receive () external payable {
        emit Received(msg.sender, msg.value);
    }

    function claimPeriodLeft() public view returns (uint256 claimPeriodLeft) {
        if( block.timestamp >= claimDeadline) {
            return (0);
        } else {
            return (claimDeadline - block.timestamp);
        }
    }

    modifier withdrawalDeadlineReached( bool requireReached ) {
        uint256 timeRemaining = withdrawalTimeLeft();
        if( requireReached ) {
            require(timeRemaining == 0, "Withdrawal period is not reached yet");
        } else {
            require(timeRemaining > 0, "Withdrawal period has been reached");
        }
        _;
    }

    modifier claimDeadlineReached( bool requireReached ) {
        uint256 timeRemaining = claimPeriodLeft();
        if( requireReached ) {
            require(timeRemaining == 0, "Claim deadline is not reached yet");
        } else {
            require(timeRemaining > 0, "Claim deadline has been reached");
        }
        _;
    }

    modifier notCompleted() {
        bool completed = exampleExternalContract.completed();
        require(!completed, "Stake already completed!");
        _;
    }


}
