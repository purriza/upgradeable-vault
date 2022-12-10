// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./OmniToken.sol";

/**
 * @title EternalStorageV1
 * @dev This contract holds all the necessary state variable to manage the storage of the contract.  
 */

contract EternalStorageV1 {

    bool initialized;

    /// @dev Variable to store the owner of the implementation/storage 
    address public owner;

    /// @dev Variable to store the instance of the rewards token (OmniToken.sol)
    OmniToken public rewardsToken;

    /// @dev Variable to store the instance of the Uniswap LP token 
    address public uniswapLPTokenAddress;

    /// @dev Deposit struct to hold the information from the deposits
    struct Deposit {
        address depositor;
        uint256 amount;
        uint256 enterTime;
        uint256 lockingPeriod;
        uint256 finishAt;
        uint256 rewardsMultiplier;
        uint256 lastTimeClaimed;
        uint256 pendingRewards;
        uint256 claimedRewards; 
        uint256 lastTimeComputedRewards;
        bool completed;
    }
    /// @dev List to keep track of the deposits
    mapping(uint256 => Deposit) public allDeposits;
    uint256 public nextDepositId;

    /// @dev Constant to avoid divisions resulting in 0
    uint public constant MULTIPLIER = 1e18; // TO-DO Possible to be private?

    /// @dev Variable to store the rewards token issuance per year
    uint256 public rewardsIssuancePerYear; // TO-DO Possible to be private?

    /// @dev Variable to keep track of the total amount of LP tokens deposited
    uint256 public totalSupply;

    /// @dev Variable to keep track of the total weighted amount of LP tokens deposited (Depending of the locking period of each Deposit)
    uint256 public weightedTotalSupply;

    /// @dev Events to keep track of the different actions happening on the contract
    event Deposited(address indexed depositor, uint256 amount, uint256 lockingPeriod, uint256 timestamp);
    event Claimed(uint256 depositId, uint256 rewardsAmount, uint256 timestamp);
    event Withdrawed(uint256 depositId, uint256 timestamp);

    // Testing // TO-DO Delete
    event LogUint(string description, uint256 value);
    event LogAddress(string description, address value);
    event LogString(string description);
}