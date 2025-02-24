// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "hardhat/console.sol";
import "./ExampleExternalContract.sol";

/**
 * @title Staker Contract
 * @author scaffold-eth
 * @notice A contract that allows users to stake ETH
 */
contract Staker {
    // External contract that will hold staked funds
    ExampleExternalContract public exampleExternalContract;

    // Balances of the user's staked funds
    mapping(address => uint256) public balances;

    // Staking threshold
    uint256 public constant threshold = 1 ether;

    // Staking deadline (Non-immutable)
    uint256 public deadline;

    // Contract's Events
    event Stake(address indexed, uint256); //(sender,amount)

    /**
     * @notice Contract Constructor
     * @param exampleExternalContractAddress Address of the external contract that will hold staked funds
     */
    constructor(address exampleExternalContractAddress) {
        exampleExternalContract = ExampleExternalContract(exampleExternalContractAddress);
        deadline = block.timestamp + 120 seconds; //30 seconds was too less , the sepolia trasaction required more time
    }

    /**
     * @notice Stake method that updates the user's balance
     */
    function stake() public payable {
        // Check if the deadline has passed
        require(block.timestamp < deadline, "Deadline has passed");

        // Check if staking has not been completed
        require(!exampleExternalContract.completed(), "Staking process already completed");

        // Update the user's balance
        balances[msg.sender] += msg.value;

        // Emit the event to notify the blockchain that staking has been recorded
        emit Stake(msg.sender, msg.value);
    }

    /**
     * @notice Execute function that transfers funds to the external contract if threshold is met
     */
    function execute() public {
        // Check if staking has not been completed
        require(!exampleExternalContract.completed(), "Staking process already completed");

        // Ensure the deadline has passed
        require(block.timestamp >= deadline, "Deadline not reached yet");

        // Check if the contract has enough ETH to reach the threshold
        uint256 contractBalance = address(this).balance;
        require(contractBalance >= threshold, "Threshold not reached");

        // Execute the external contract, transferring all the balance
        (bool sent, ) = address(exampleExternalContract).call{ value: contractBalance }(
            abi.encodeWithSignature("complete()")
        );
        require(sent, "exampleExternalContract.complete failed");
    }

    /**
     * @notice Allow users to withdraw their balance from the contract if the deadline has passed but the stake is not completed
     */
    function withdraw() public {
        // Ensure the deadline has passed
        require(block.timestamp >= deadline, "Deadline is not reached yet");

        // Ensure staking is not completed
        require(!exampleExternalContract.completed(), "Staking process already completed");

        // Ensure the user has a balance to withdraw
        uint256 userBalance = balances[msg.sender];
        require(userBalance > 0, "You don't have balance to withdraw");

        // Reset the user's balance before transferring funds (prevents re-entrancy attacks)
        balances[msg.sender] = 0;

        // Transfer the user's balance back to them
        (bool sent, ) = msg.sender.call{ value: userBalance }("");
        require(sent, "Failed to send user balance back to the user");
    }

    /**
     * @notice Returns the number of seconds remaining until the deadline is reached
     */
    function timeLeft() public view returns (uint256) {
        if (block.timestamp >= deadline) {
            return 0;
        } else {
            return deadline - block.timestamp;
        }
    }

    /**
     * @notice Special function to receive ETH and automatically stake it
     */
    receive() external payable {
        stake();
    }
}
