// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./OmniToken.sol";

//import "lib/v2-core/contracts/UniswapV2ERC20.sol";

/**
 * @title EternalStorage
 * @dev This contract holds all the necessary state variable to manage the storage of the contract.  
 */

contract EternalStorage {

    bool initialized;

    // TO-DO Possible collision with owner in Proxy, check where it's best to store this variable (Need to use it on the Proxy and on the Vault)
    /// @dev Variable to store the owner of the implementation/storage 
    address public owner;

    /// @dev Variable to store the instance of the rewards token (OmniToken.sol)
    OmniToken public rewardsToken;

    /// @dev Variable to store the instance of the Uniswap LP token 
    //UniswapV2ERC20 public uniswapLPToken; // TO-DO Couldn't use it due to Solidity version =0.5.16;
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
        uint256[] intervals; // Array to store the interval IDs to which it belongs the Deposit
    }
    /// @dev List to keep track of the deposits
    mapping(uint256 => Deposit) public allDeposits;
    uint256 public nextDepositId;

    /// @dev Interval struct to hold the information from the intervals
    struct Interval {
        uint256 initialDate;
        uint256 finalDate;
        uint256 totalSupply;
        uint256[] deposits; // Array to store the deposit IDs that belong to this interval (Repeated from Deposit Struct to avoid more loops) // TO-DO       
    }
    /// @dev List to keep track of the intervals
    mapping(uint256 => Interval) public allIntervals;
    uint256 public nextIntervalId;

    /// @dev Constant to avoid divisions resulting in 0 // TO-DO Where to use it?
    uint public constant MULTIPLIER = 1e18; // TO-DO Possible to be private?

    /// @dev Variable to store the rewards token issuance per year
    uint256 public rewardsIssuancePerYear; // TO-DO Possible to be private?

    /// @dev Variable to keep track of the total amount of LP tokens deposited
    uint256 public totalSupply;

    /// @dev Events to keep track of the different actions happening on the contract
    event Deposited(address indexed depositor, uint256 amount, uint256 lockingPeriod, uint256 timestamp);
    event Claimed(uint256 depositId, uint256 rewardsAmount, uint256 timestamp);
    event Withdrawed(uint256 depositId, uint256 timestamp);

    // Testing // TO-DO Delete
    event LogUint(string description, uint256 value);
    event LogString(string description);
}