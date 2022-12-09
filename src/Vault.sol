// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./OmniToken.sol";
import "./EternalStorage.sol";

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
//import "lib/v2-core/contracts/UniswapV2ERC20.sol";

/**
 * @title Vault
 * @dev Contract that accepts deposits of Uniswap LP tokens and locks them for a period.
 * The user gets rewards in the form of OmniTokens for the deposites LP tokens. 
 * This rewards are distributed proportionally amongs the LP depositors based on their deposits. 
 * Users can claim their pending rewards at any time.
 */
contract Vault is EternalStorage, Initializable {
    using Math for uint256;

    // TO-DO Not working with the initializer Modifier
    function initialize(uint256 _rewardsIssuancePerYear, address _uniswapLPTokenAddress, address _rewardsTokenAddress) public /*initializer*/ {
        require(!initialized, "Already initialized");

        rewardsIssuancePerYear = _rewardsIssuancePerYear;
        uniswapLPTokenAddress = _uniswapLPTokenAddress;

        owner = msg.sender;
        rewardsToken = new OmniToken(_rewardsTokenAddress);
        //uniswapLPToken = UniswapV2ERC20(uniswapLPTokenAddress); // TO-DO Solidity =0.5.16;

        // We need to keep track of the next deposit ID
        nextDepositId = 0;

        // We need to keep track of the next interval ID
        nextIntervalId = 0;

        initialized = true;
    }

    // *** Modifiers ***

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    modifier depositExists(uint256 depositId) {
        require(depositId < nextDepositId, "Deposit does not exist");
        _;
    }

    // *** Public Functions ***

    /**
     * @notice Public function that allows the owner to change the rewards issuance per year
     * @param newRewardsIssuancePerYear New rewards issuance
     */
    function updateRewardsIssuancePerYear(uint256 newRewardsIssuancePerYear) external onlyOwner {
        rewardsIssuancePerYear = newRewardsIssuancePerYear;
    }

    /**
     * @notice Public function that allows to deposit LP tokens
     * @param amount Amount of LP tokens
     * @param lockingPeriod Locking period
     */
    function deposit(uint256 amount, uint256 lockingPeriod) external {
        require(lockingPeriod == 6 || lockingPeriod == 12 || lockingPeriod == 24 || lockingPeriod == 48, "Locking period has to be 6 months or 1, 2 or 4 years.");

        // LP Tokens transfer (Depositor has to approve the amount before calling deposit) // TO-DO Solidity =0.5.16;
        // uniswapLPToken.transfer(address(this), amount);
        // TO-DO Find better way?
        (bool success, ) = uniswapLPTokenAddress.call(
            abi.encodeWithSignature(
                "transferFrom(address,address,uint256)",
                msg.sender,
                address(this),
                amount
            )
        );
        require(success, "Transfer failed. You have to approve the Vault to transfer the funds or you don't have enough");
        
        // Everytime a deposit is made, we compute the pending rewards for all the active deposits in the past period
        computeAllDepositPendingRewards();

        // Depending of the locking period the deposit gets a multiplier for the rewards
        uint256 rewardsMultiplier = 1;
        if (lockingPeriod == 12) {
            rewardsMultiplier = 2;
        }
        else if (lockingPeriod == 24) {
            rewardsMultiplier = 4;
        }
        else if (lockingPeriod == 48) {
            rewardsMultiplier = 8;
        }

        // We add the Deposit
        allDeposits[nextDepositId].depositor = msg.sender;
        allDeposits[nextDepositId].amount = amount;
        allDeposits[nextDepositId].enterTime = block.timestamp;
        allDeposits[nextDepositId].lockingPeriod = lockingPeriod * 30 * 24 * 60 * 60;
        allDeposits[nextDepositId].finishAt = block.timestamp + (lockingPeriod * 30 * 24 * 60 * 60);
        allDeposits[nextDepositId].rewardsMultiplier = rewardsMultiplier;
        allDeposits[nextDepositId].lastTimeClaimed = block.timestamp;
        allDeposits[nextDepositId].pendingRewards = 0;
        allDeposits[nextDepositId].claimedRewards = 0;
        allDeposits[nextDepositId].completed = false;

        // We need to check the state of the Intervals with the new Deposit
        
        // We compute the totalSupply that will apply on it, checking the stored Deposits/Intervals
        // We also need to modify/add Intervals, depending of the Initial/Final Dates of them
        emit LogUint("ENTER DEPOSIT - amount", amount);
        uint256 totalSupplyNewInterval = amount * rewardsMultiplier;
        uint256[] memory depositsInterval = new uint256[](nextDepositId);
        uint256[] memory intervalsDeposit = new uint256[](nextIntervalId);

        uint256 initialDateNewInterval = block.timestamp;
        uint256 finalDateNewInterval = block.timestamp + (lockingPeriod * 30 * 24 * 60 * 60);
        emit LogUint("DEPOSIT - initialDateNewInterval", initialDateNewInterval);
        emit LogUint("DEPOSIT - finalDateNewInterval", finalDateNewInterval);

        uint256 storedIntervalsNumber = nextIntervalId;
        uint256 updatedInitialDateNewInterval;
        uint256 updatedFinalDateNewInterval;

        // We check the stored Intervals in order to restructure them
        for (uint256 i = 0; i < storedIntervalsNumber; i++) {

            emit LogUint("DEPOSIT - allIntervals[i]", i);
            emit LogUint("DEPOSIT - block.timestamp", block.timestamp);
            emit LogUint("DEPOSIT - allIntervals[i].enterDate", allIntervals[i].initialDate);
            emit LogUint("DEPOSIT - allIntervals[i].finalDate", allIntervals[i].finalDate);
            emit LogUint("DEPOSIT - allIntervals[i].totalSupply", allIntervals[i].totalSupply);

            bool intervalsDontOverlap = initialDateNewInterval >= allIntervals[i].finalDate || finalDateNewInterval <= allIntervals[i].initialDate;
            uint256 storedIntervalFinalDate;

            // 1. Check if the newInterval overlaps in some way with the stored Interval. If not, we pass to the next Interval
            if (!intervalsDontOverlap) {
                // 1.1 If they are the same Interval we update the totalSupply of the stored one, add the new Deposit and add the Interval to the Deposit
                if (initialDateNewInterval == allIntervals[i].initialDate && finalDateNewInterval == allIntervals[i].finalDate) {
                    emit LogString("initialDateNewInterval == allIntervals[i].initialDate && finalDateNewInterval == allIntervals[i].finalDate");
                    allIntervals[i].totalSupply = allIntervals[i].totalSupply + totalSupplyNewInterval;
                    allIntervals[i].deposits.push(nextDepositId);
                    allDeposits[nextDepositId].intervals.push(i);
                }
                // 1.2 Case finalDateNewInterval >= allIntervals[i].finalDate
                else if (finalDateNewInterval >= allIntervals[i].finalDate) {
                    emit LogString("finalDateNewInterval >= allIntervals[i].finalDate");
                    storedIntervalFinalDate = allIntervals[i].finalDate;

                    // 1.2.1 Case ([0,6]) -> [0,12] --> ([0,6], [6,12])
                    //            ([0,6]) -> [2,8] --> ([0,2], [2,6], [8,12])
                    if (initialDateNewInterval >= allIntervals[i].initialDate) {
                        emit LogString("initialDateNewInterval >= allIntervals[i].initialDate");
                        if (initialDateNewInterval == allIntervals[i].initialDate) {
                            allIntervals[i].totalSupply = allIntervals[i].totalSupply + totalSupplyNewInterval;
                            allIntervals[i].deposits.push(nextDepositId);
                            allDeposits[nextDepositId].intervals.push(i);
                        }
                        else {
                            // 1.2.1.1 We modify the stored interval [allIntervals[i].initialDate, allIntervals[i].finalDate] to [allIntervals[i].initialDate, initialDateNewInterval]
                            allIntervals[i].finalDate = initialDateNewInterval;

                            // 1.2.1.2 We add a new Interval to cover the time [initialDateNewInterval, allIntervals[i].finalDate (storedIntervalFinalDate)]
                            allIntervals[nextIntervalId].initialDate = initialDateNewInterval;
                            allIntervals[nextIntervalId].finalDate = storedIntervalFinalDate;
                            allIntervals[nextIntervalId].totalSupply = allIntervals[i].totalSupply + totalSupplyNewInterval;
                            allIntervals[nextIntervalId].deposits = allIntervals[i].deposits;
                            allIntervals[nextIntervalId].deposits.push(nextDepositId);
                            for (uint256 j = 0; j < allIntervals[i].deposits.length; j++) {
                                allDeposits[allIntervals[i].deposits[j]].intervals.push(nextIntervalId);
                            }
                            allDeposits[nextDepositId].intervals.push(nextIntervalId);
                            nextIntervalId++;
                        }
                        // 1.2.1.3 We update the initialDate of the newInterval in order to compare it with the next Interval or to add the new One
                        updatedInitialDateNewInterval = storedIntervalFinalDate;
                        updatedFinalDateNewInterval = finalDateNewInterval;
                    }
                    // 1.2.2 Case ([6,12], [0,6]) -> [2,26] --> ([0,6], [6,12], [12,26])
                    else {
                        emit LogString("initialDateNewInterval < allIntervals[i].initialDate");
                        // The time [initialDateNewInterval, allIntervals[nextIntervalId].initialDate] is already covered or will be 

                        // 1.2.2.1 We update the totalSupply of the stored one, add the new Deposit and add the Interval to the Deposit
                        allIntervals[nextIntervalId].totalSupply = allIntervals[i].totalSupply + totalSupplyNewInterval;
                        allIntervals[nextIntervalId].deposits.push(nextDepositId);
                        allDeposits[nextDepositId].intervals.push(i);

                        // TO-DO The stored Interval is completely covered by the new one -> We don't know how to add the [0,6] and [12,26] at this moment
                        // 1.2.2.2 We update the initialDate of the newInterval in order to compare it with the next Interval or to add the new One
                        updatedInitialDateNewInterval = finalDateNewInterval;
                        updatedFinalDateNewInterval = storedIntervalFinalDate;
                    }
                
                    // 1.2.3 If there aren't more Intervals, we add a new one to cover the time left [allIntervals[i].finalDate, finalDateNewInterval]
                    // 1.2.1 [8,12] / 1.2.2 [12,26]
                    if (i == storedIntervalsNumber - 1) {
                        allIntervals[nextIntervalId].initialDate = updatedInitialDateNewInterval;
                        allIntervals[nextIntervalId].finalDate = updatedFinalDateNewInterval;
                        allIntervals[nextIntervalId].totalSupply = totalSupplyNewInterval;
                        allIntervals[nextIntervalId].deposits.push(nextDepositId);
                        allDeposits[nextDepositId].intervals.push(nextIntervalId);
                        nextIntervalId++;
                    }
                    else {
                        // We update the initialDate of the newInterval in order to compare it with the next Interval
                        initialDateNewInterval = updatedInitialDateNewInterval;
                        finalDateNewInterval = updatedFinalDateNewInterval;
                    }
                }
                // 1.3 finalDateNewInterval < allIntervals[i].finalDate
                else if (finalDateNewInterval < allIntervals[i].finalDate) {
                    emit LogString("finalDateNewInterval < allIntervals[i].finalDate");

                    // 1.3.1 Case ([0,12]) -> [2,8] --> ([8,12], [0,2], [2,8])
                    if (initialDateNewInterval >= allIntervals[i].initialDate) {
                        // TO-DO
                        if (initialDateNewInterval == allIntervals[i].initialDate) {
                            
                        }
                        else {

                        }
                        emit LogString("initialDateNewInterval >= allIntervals[i].initialDate");
                        // 1.3.1.1 We add a new Interval to cover the time [allIntervals[i].initialDate, initialDateNewInterval]
                        // [0,2]
                        allIntervals[nextIntervalId].initialDate = allIntervals[i].initialDate;
                        allIntervals[nextIntervalId].finalDate = initialDateNewInterval;
                        allIntervals[nextIntervalId].totalSupply = allIntervals[i].totalSupply;
                        allIntervals[nextIntervalId].deposits = allIntervals[i].deposits;
                        for (uint256 j = 0; j < allIntervals[i].deposits.length; j++) {
                            allDeposits[allIntervals[i].deposits[j]].intervals.push(nextIntervalId);
                        }

                        nextIntervalId++;

                        // 1.3.1.2 We add a new Interval to cover the time [initialDateNewInterval, finalDateNewInterval]
                        // [2,8]
                        allIntervals[nextIntervalId].initialDate = initialDateNewInterval;
                        allIntervals[nextIntervalId].finalDate = finalDateNewInterval;
                        allIntervals[nextIntervalId].totalSupply = allIntervals[i].totalSupply + totalSupplyNewInterval;
                        allIntervals[nextIntervalId].deposits = allIntervals[i].deposits;
                        allIntervals[nextIntervalId].deposits.push(nextDepositId);
                        for (uint256 j = 0; j < allIntervals[i].deposits.length; j++) {
                            allDeposits[allIntervals[i].deposits[j]].intervals.push(nextIntervalId);
                        }
                        allDeposits[nextDepositId].intervals.push(nextIntervalId);

                        nextIntervalId++;

                        // 1.3.1.3 We modify the stored interval [allIntervals[i].initialDate, allIntervals[i].finalDate] to [finalDateNewInterval, allIntervals[i].finalDate]
                        // [8,12]
                        // CAUTION: Possibility to keep Deposits inside the Interval that are no longer part of it
                        allIntervals[i].initialDate = finalDateNewInterval;
                    }
                    // 1.3.2 Case ([6,12], [0,6]) -> [2,8] --> ([6,8], [0,6], [8,12])
                    else {
                        emit LogString("initialDateNewInterval < allIntervals[i].initialDate");
                        storedIntervalFinalDate = allIntervals[i].finalDate;
                        // 1.3.2.1 We modify the stored interval [allIntervals[i].initialDate, allIntervals[i].finalDate] to [allIntervals[i].initialDate, initialDateNewInterval]
                        // CAUTION: Possibility to keep Deposits inside the Interval that are no longer part of it
                        // [6,8]
                        allIntervals[i].finalDate = initialDateNewInterval;
                        allIntervals[i].totalSupply = allIntervals[i].totalSupply + totalSupplyNewInterval;
                        allIntervals[i].deposits.push(nextDepositId);
                        allDeposits[nextDepositId].intervals.push(i);

                        // 1.3.2.2 We add a new Interval to cover the time [finalDateNewInterval, allIntervals[i].finalDate]
                        // [8,12]
                        allIntervals[nextIntervalId].initialDate = finalDateNewInterval;
                        allIntervals[nextIntervalId].finalDate = storedIntervalFinalDate;
                        allIntervals[nextIntervalId].totalSupply = allIntervals[i].totalSupply + totalSupplyNewInterval;
                        allIntervals[nextIntervalId].deposits = allIntervals[i].deposits;
                        allIntervals[nextIntervalId].deposits.push(nextDepositId);
                        for (uint256 j = 0; j < allIntervals[i].deposits.length; j++) {
                            allDeposits[allIntervals[i].deposits[j]].intervals.push(nextIntervalId);
                        }
                        allDeposits[nextDepositId].intervals.push(nextIntervalId);

                        nextIntervalId++;

                        // 1.3.2.3 We update the initialDate of the newInterval in order to compare it with the next Interval or to add the new One
                        // [2,6]
                        updatedInitialDateNewInterval = initialDateNewInterval;
                        updatedFinalDateNewInterval = allIntervals[i].initialDate;

                        // 1.3.3 If there aren't more Intervals, we add a new one to cover the time left
                        if (i == storedIntervalsNumber - 1) {
                            allIntervals[nextIntervalId].initialDate = updatedInitialDateNewInterval;
                            allIntervals[nextIntervalId].finalDate = updatedFinalDateNewInterval;
                            allIntervals[nextIntervalId].totalSupply = totalSupplyNewInterval;
                            allIntervals[nextIntervalId].deposits.push(nextDepositId);
                            allDeposits[nextDepositId].intervals.push(nextIntervalId);
                            nextIntervalId++;
                        }
                        else {
                            // We update the initialDate of the newInterval in order to compare it with the next Interval
                            initialDateNewInterval = updatedInitialDateNewInterval;
                            finalDateNewInterval = updatedFinalDateNewInterval;
                        }
                    }
                }
            }
            // The Intervals don't overlap
            else {
                emit LogString("The Intervals don't overlap");
                // If there aren't more Intervals, we add a new the new one
                if (i == storedIntervalsNumber - 1) {
                    allIntervals[nextIntervalId].initialDate = initialDateNewInterval;
                    allIntervals[nextIntervalId].finalDate = finalDateNewInterval;
                    allIntervals[nextIntervalId].totalSupply = allIntervals[i].totalSupply + totalSupplyNewInterval;
                    allIntervals[nextIntervalId].deposits.push(nextDepositId);
                    allDeposits[nextDepositId].intervals.push(nextIntervalId);
                    nextIntervalId++;
                }
            }
        }

        // If it's the first Interval/Deposit, we just add it
        if (nextIntervalId == 0) {
            allIntervals[nextIntervalId].initialDate = initialDateNewInterval;
            allIntervals[nextIntervalId].finalDate = finalDateNewInterval;
            allIntervals[nextIntervalId].totalSupply = totalSupplyNewInterval;
            allIntervals[nextIntervalId].deposits.push(nextDepositId);
            allDeposits[nextDepositId].intervals.push(nextIntervalId);
            nextIntervalId++;
        }
        nextDepositId++;

        emit LogString("INTERVALS LOOP");
        for(uint256 z = 0; z < nextIntervalId; z++) {
            emit LogUint("DEPOSIT - Interval ID", z);
            emit LogUint("DEPOSIT - allIntervals[z].initialDate", allIntervals[z].initialDate);
            emit LogUint("DEPOSIT - allIntervals[z].finalDate", allIntervals[z].finalDate);
            emit LogUint("DEPOSIT - allIntervals[z].totalSupply", allIntervals[z].totalSupply);
            for (uint256 y = 0; y < allIntervals[z].deposits.length; y++) {
                emit LogUint("DEPOSIT - allIntervals[z].deposits[y]", allIntervals[z].deposits[y]);
            }
        }
        emit LogString("DEPOSITS LOOP");
        for (uint256 v = 0; v < nextDepositId; v++) {
            emit LogUint("DEPOSIT - Deposit ID", v);
            for (uint256 x = 0; x < allDeposits[v].intervals.length; x++) {
                emit LogUint("DEPOSIT - allDeposits[v].intervals[x]", allDeposits[v].intervals[x]);
            }
        }

        totalSupply = totalSupply + amount;

        emit Deposited(msg.sender, amount, lockingPeriod, block.timestamp);
    }

    /**
     * @notice Public function that allows to withdraw LP tokens
     * @param depositId Deposit ID
     */
    function withdrawDeposit (uint256 depositId) external depositExists(depositId) /*nonReentrant*/ {
        // Check if the caller if the actual depositor of the depositId 
        // CAREFUL: This wont allow the owner of the contract to withdraw in case that some depositor leaves, forgets, etc
        address depositor = allDeposits[depositId].depositor;
        require(msg.sender == depositor, "Only the depositor can withdraw his tokens");

        // Locking period has had to end
        require(allDeposits[depositId].enterTime + allDeposits[depositId].lockingPeriod < block.timestamp, "Locking period hasn't ended yet");

        totalSupply = totalSupply - allDeposits[depositId].amount;

        // LP Tokens transfer (Vault has to approve the amount) // TO-DO Solidity =0.5.16;
        //uniswapLPToken.transfer(allDeposits[depositId].depositor, allDeposits[depositId].amount);
        // TO-DO Find better way?
        (bool success, ) = uniswapLPTokenAddress.call(
            abi.encodeWithSignature(
                "transferFrom(address,address,uint256)",
                address(this),
                allDeposits[depositId].depositor,
                allDeposits[depositId].amount
            )
        );
        require(success, "transferFrom failed");

        // Everytime a deposit is withdrawed, we compute the pending rewards for all the active deposits in the past period
        computeAllDepositPendingRewards();

        // TO-DO Check if it's a better way to delete, this way is just reseting the index, not removing it from the array (It would be better but will change all deposit IDs)
        delete allDeposits[depositId];

        emit Withdrawed(depositId, block.timestamp);
    }

    /**
     * @notice Public function that allows to claim rewards of a deposit
     * @param depositId Id from the deposit 
     */
    function claimRewards(uint256 depositId) public depositExists(depositId) /*nonReentrant*/ {
        // Check if the caller if the actual depositor of the depositId 
        // CAREFUL: This wont allow the owner of the contract to claim rewards in case that some depositor leaves, forgets, etc
        address depositor = allDeposits[depositId].depositor;
        require(msg.sender == depositor, "Only the depositor can claim his rewards");
 
        // If the deposit is marked as "completed" the locking period has passed and its rewards have already been computed
        if (!allDeposits[depositId].completed) {
            computePendingRewardsByDeposit(depositId);
        }

        // Check if the deposit has any pending rewards
        uint256 pendingRewardsOfDeposit = allDeposits[depositId].pendingRewards;
        require(pendingRewardsOfDeposit > 0, "Pending rewards has to be greater than 0.");

        // Check last time claimed
        require(allDeposits[depositId].lastTimeClaimed < block.timestamp, "You must wait to claim rewards again.");

        // Update the deposit pendingRewards before transfering to avoid Reentrancy
        allDeposits[depositId].pendingRewards = 0;
        // Send the tokens to the depositor
        rewardsToken.transfer(depositor, pendingRewardsOfDeposit);

        // Update the deposit claimedRewards and lastTimeClaimed
        uint256 claimedRewardsOfDeposit = allDeposits[depositId].claimedRewards;
        allDeposits[depositId].claimedRewards = claimedRewardsOfDeposit + pendingRewardsOfDeposit;
        allDeposits[depositId].lastTimeClaimed = block.timestamp;

        emit Claimed(depositId, pendingRewardsOfDeposit, block.timestamp);
    }

    // *** Internal Functions *** 

    /**
     * @notice Internal function that computes the pending rewards for all deposits in the past period
     */
    function computeAllDepositPendingRewards() internal {
        for (uint i = 0; i < nextDepositId; i++) {
            emit LogUint("nextDepositId", i);
            if (!allDeposits[i].completed) {
                computePendingRewardsByDeposit(i);
            }
        }
    }

    /**
     * @notice Internal function that computes the pending rewards for a deposit Id
     * @param depositId Id from the deposit 
     */
    function computePendingRewardsByDeposit(uint256 depositId) internal depositExists(depositId) {  
        // For each interval that the deposit has been part of, we compute its rewards
        uint256 rewardsRatePerDeposit;
        uint256 timePassedInsideInterval;
        uint256 rewardsPerDeposit;
        emit LogUint("allDeposits[depositId].intervals.length", allDeposits[depositId].intervals.length);
        for (uint i = 0; i < allDeposits[depositId].intervals.length; i++) {
            uint256 intervalId = allDeposits[depositId].intervals[i];
            if (allIntervals[intervalId].initialDate <= block.timestamp) {
                emit LogUint("intervalId", intervalId);

                emit LogUint("allDeposits[depositId].amount", allDeposits[depositId].amount);
                emit LogUint("allDeposits[depositId].rewardsMultiplier", allDeposits[depositId].rewardsMultiplier);
                emit LogUint("allDeposits[depositId].amount * allDeposits[depositId].rewardsMultiplier", allDeposits[depositId].amount * allDeposits[depositId].rewardsMultiplier);
                emit LogUint("allIntervals[i].totalSupply", allIntervals[intervalId].totalSupply);
                //rewardsRatePerDeposit = ((allDeposits[depositId].amount * allDeposits[depositId].rewardsMultiplier) * MULTIPLIER / allIntervals[intervalId].totalSupply);
                rewardsRatePerDeposit = (allDeposits[depositId].amount * allDeposits[depositId].rewardsMultiplier) * MULTIPLIER;
                emit LogUint("rewardsRatePerDeposit", rewardsRatePerDeposit);

                // In order to get the time that has passed since last claim we have to take the minimum between block.timestamp and the time when the locking period ends
                //timePassedSinceLastClaimed = block.timestamp.min(allDeposits[depositId].finishAt) - allDeposits[depositId].lastTimeClaimed;
                emit LogUint("allIntervals[i].finalDate", allIntervals[intervalId].finalDate);
                emit LogUint("block.timestamp", block.timestamp);
                emit LogUint("allDeposits[depositId].finishAt", allDeposits[depositId].finishAt);
                emit LogUint("allIntervals[i].initialDate", allIntervals[intervalId].initialDate);
                emit LogUint("allDeposits[i].lastTimeComputedRewards", allDeposits[depositId].lastTimeComputedRewards);
                emit LogUint("allIntervals[intervalId].finalDate.min(block.timestamp.min(allDeposits[depositId].finishAt))", allIntervals[intervalId].finalDate.min(block.timestamp.min(allDeposits[depositId].finishAt)));
                emit LogUint("allDeposits[i].allIntervals[intervalId].initialDate.max(allDeposits[depositId].lastTimeComputedRewards", allIntervals[intervalId].initialDate.max(allDeposits[depositId].lastTimeComputedRewards));
                timePassedInsideInterval = allIntervals[intervalId].finalDate.min(block.timestamp.min(allDeposits[depositId].finishAt)) - allIntervals[intervalId].initialDate.max(allDeposits[depositId].lastTimeComputedRewards);
                emit LogUint("timePassedInsideInterval", timePassedInsideInterval);

                //emit LogUint("getRewardsPerSecond()", getRewardsPerSecond());
                //emit LogUint("rewardsRatePerDeposit * (timePassedInsideInterval * getRewardsPerSecond())", rewardsRatePerDeposit * (timePassedInsideInterval * getRewardsPerSecond()));
                //rewardsPerDeposit = (rewardsRatePerDeposit * (timePassedInsideInterval * getRewardsPerSecond())) / (MULTIPLIER * MULTIPLIER);
                emit LogUint("getSecondsPerYear()", getSecondsPerYear());
                rewardsPerDeposit = (rewardsRatePerDeposit * (timePassedInsideInterval * rewardsIssuancePerYear)) / (allIntervals[intervalId].totalSupply * getSecondsPerYear() * MULTIPLIER);
                emit LogUint("rewardsPerDeposit", rewardsPerDeposit);
                
                allDeposits[depositId].pendingRewards += rewardsPerDeposit;
                emit LogUint("allDeposits[depositId].pendingRewards", allDeposits[depositId].pendingRewards);

                // If it's the last interval of the deposit we set its lastTimeComputedRewards
                if (i == allDeposits[depositId].intervals.length - 1 ) {
                    allDeposits[depositId].lastTimeComputedRewards = block.timestamp;
                }
            }
                
        }

        // TO-DO Need to optimize, 2 same loops
        for (uint i = 0; i < allDeposits[depositId].intervals.length; i++) {
            if (allIntervals[allDeposits[depositId].intervals[i]].finalDate < block.timestamp) {
                delete allDeposits[depositId].intervals;
            }
        }

        // If the deposit had already ended and wasn't marked as completed we do it
        if (block.timestamp >= allDeposits[depositId].finishAt && !allDeposits[depositId].completed) {
            allDeposits[depositId].completed = true;
        }
    }

    /**
     * @notice Internal function that computes seconds per year
     */
    function getSecondsPerYear() internal view returns (uint256) {
        return (12 * 30 * 24 * 60 * 60); // Months * Days * Hours * Minutes * Seconds
    }

    // Not used due to lose of precision producing missed rewards 
    /**
     * @notice Internal function that computes the rewards per second
     */
    function getRewardsPerSecond() internal view returns (uint256) {
        return rewardsIssuancePerYear * MULTIPLIER / (12 * 30 * 24 * 60 * 60); // Months * Days * Hours * Minutes * Seconds
    }
}