// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./OmniToken.sol";
import "./EternalStorageV1.sol";

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";

/**
 * @title VaultV1
 * @dev Contract that accepts deposits of Uniswap LP tokens and locks them for a period.
 * The user gets rewards in the form of OmniTokens for the deposites LP tokens. 
 * This rewards are distributed proportionally amongs the LP depositors based on their deposits. 
 * Users can claim their pending rewards at any time.
 */
contract VaultV1 is EternalStorageV1, Initializable {
    using Math for uint256;

    // TO-DO Not working with the initializer Modifier
    function initialize(uint256 _rewardsIssuancePerYear, address _uniswapLPTokenAddress, address _rewardsTokenAddress) public /*initializer*/ {
        require(!initialized, "Already initialized");

        rewardsIssuancePerYear = _rewardsIssuancePerYear;
        uniswapLPTokenAddress = _uniswapLPTokenAddress;

        owner = msg.sender;
        rewardsToken = new OmniToken(_rewardsTokenAddress);
        rewardsToken.mint(); // TO-DO Token mintable only from the Vault (Use of ROLES?)

        // We need to keep track of the next deposit ID
        nextDepositId = 0;

        totalSupply = 0;
        weightedTotalSupply = 0;

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

        // LP Tokens transfer (Depositor has to approve the amount before calling deposit)
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

        userDeposits[nextDepositId] = nextDepositId;

        // We add the Deposit (It will be moved on the sort function, it's just to have the correct number of Deposits on the mapping)
        allDeposits[nextDepositId].id = nextDepositId;
        allDeposits[nextDepositId].depositor = msg.sender;
        allDeposits[nextDepositId].amount = amount;
        allDeposits[nextDepositId].enterTime = block.timestamp;
        allDeposits[nextDepositId].lockingPeriod = lockingPeriod * 30 * 24 * 60 * 60;
        allDeposits[nextDepositId].finishAt = block.timestamp + (lockingPeriod * 30 * 24 * 60 * 60);
        allDeposits[nextDepositId].rewardsMultiplier = rewardsMultiplier;
        allDeposits[nextDepositId].lastTimeClaimed = 0;
        allDeposits[nextDepositId].pendingRewards = 0;
        allDeposits[nextDepositId].claimedRewards = 0;
        allDeposits[nextDepositId].completed = false;
        
        // We order the allDeposits mapping 
        if (nextDepositId > 0) {
            insertDepositByFinishAt(allDeposits[nextDepositId], nextDepositId/2);
        }

        // We update the weightedTotalSupply and the totalSupply
        weightedTotalSupply = weightedTotalSupply + (amount * rewardsMultiplier);
        totalSupply = totalSupply + amount;

        nextDepositId++;

        emit Deposited(msg.sender, amount, lockingPeriod, block.timestamp);
    }

    /**
     * @notice Public function that allows to withdraw LP tokens
     * @param depositId Deposit ID
     */
    function withdrawDeposit (uint256 depositId) external depositExists(depositId) /*nonReentrant*/ {
        // We need to replace the depositId passed as an argument to the correct one from the ordered mapping of userDeposits
        depositId = userDeposits[depositId];
        
        // Check if the caller if the actual depositor of the depositId 
        // CAREFUL: This wont allow the owner of the contract to withdraw in case that some depositor leaves, forgets, etc
        address depositor = allDeposits[depositId].depositor;
        require(msg.sender == depositor, "Only the depositor can withdraw his tokens");

        // Locking period has had to end
        require(allDeposits[depositId].enterTime + allDeposits[depositId].lockingPeriod < block.timestamp, "Locking period hasn't ended yet");

        // LP Tokens transfer (Vault has to approve the amount)
        (bool success, ) = uniswapLPTokenAddress.call(
            abi.encodeWithSignature(
                "approve(address,uint256)",
                address(this),
                allDeposits[depositId].amount
            )
        );
        require(success, "approve failed");
        (success, ) = uniswapLPTokenAddress.call(
            abi.encodeWithSignature(
                "transferFrom(address,address,uint256)",
                address(this),
                allDeposits[depositId].depositor,
                allDeposits[depositId].amount
            )
        );
        require(success, "transferFrom failed");

        // Everytime a deposit is withdrawed, we compute the pending rewards for all the active deposits
        computeAllDepositPendingRewards();

        // TO-DO Check if there's a better way to delete, this way is just reseting the index, not removing it from the array (It would be better but will change all deposit IDs)
        delete allDeposits[depositId];

        // Update the weightedTotalSupply and totalSupply
        weightedTotalSupply -= allDeposits[depositId].amount * allDeposits[depositId].rewardsMultiplier;
        totalSupply -= allDeposits[depositId].amount;

        emit Withdrawed(depositId, block.timestamp);
    }

    /**
     * @notice Public function that allows to claim rewards of a deposit
     * @param depositId Id from the deposit 
     */
    function claimRewards(uint256 depositId) public depositExists(depositId) /*nonReentrant*/ {
        // We need to replace the depositId passed as an argument to the correct one from the ordered mapping of userDeposits
        depositId = userDeposits[depositId];
        
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
     * @notice Internal function that adds a new Deposit to the allDeposits mapping keeping it ordered by the finishAt field of the Deposits
     * @param newDeposit Deposit to be inserted
     * @param index Index of the mapping where the Deposit will be inserted
     * @dev This function implements a sort using an algorithm in between the traditional merge and quick sort
     */
    function insertDepositByFinishAt(Deposit memory newDeposit, uint256 index) internal {
        // End conditions
        // If the Deposit has a bigger finishAt than the last Deposit stored -> It has to be at the last place of the mapping
        if (index == nextDepositId && newDeposit.finishAt >= allDeposits[index].finishAt) {
            insertDepositAtIndex(newDeposit, index);
        }
        // If the Deposit has a lower finishAt than the first Deposit stored -> It has to be at the first place of the mapping
        else if (index == 0 && newDeposit.finishAt < allDeposits[index].finishAt) {
            insertDepositAtIndex(newDeposit, index);
        }
        // If the Deposit has a finishAt value between the index Deposit and the next one -> It has at be on index + 1
        else if (newDeposit.finishAt >= allDeposits[index].finishAt && newDeposit.finishAt <= allDeposits[index+1].finishAt) {
            insertDepositAtIndex(newDeposit, index+1);
        }
        else {
            // Recursive calls
            uint256 newIndex;
            if (newDeposit.finishAt < allDeposits[index].finishAt) {
                newIndex = index != 1 ? index - (index/2) : 0;
                insertDepositByFinishAt(newDeposit, newIndex);
            }
            else {
                newIndex = index + (nextDepositId - index)/2;
                insertDepositByFinishAt(newDeposit, newIndex);
            }
        }
    }

    /**
     * @notice Internal function that inserts a Deposit into the Deposits mapping on a defined index
     * @param newDeposit Deposit to be inserted
     * @param index Index of the mapping where the Deposit will be inserted
     */
    function insertDepositAtIndex(Deposit memory newDeposit, uint256 index) internal {
        // Since the newDeposit is inserted on the last index of the mapping, we can move every Deposit from index to nextDepositId one position up
        for (uint256 i = nextDepositId; i > index; i--) {
            allDeposits[i] = allDeposits[i-1];

            // We have to keep track of the new indexes of the Deposits, in order to be able to identify them whenever the Users want to claim rewards or withdraw them
            userDeposits[allDeposits[i-1].id] = i;
        }
        allDeposits[index] = newDeposit;
        userDeposits[allDeposits[index].id] = index;
    }

    /**
     * @notice Internal function that computes the pending rewards for all deposits in the past period
     */
    function computeAllDepositPendingRewards() internal {
        for (uint i = 0; i < nextDepositId; i++) {
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
        uint256 totalWeightedSupplyDepositsExpired = 0;
        uint256 rewardsPerDeposit = 0;

        uint256 rewardsRatePerDeposit = (allDeposits[depositId].amount * allDeposits[depositId].rewardsMultiplier) * MULTIPLIER;
        uint256 timePassedSinceLastTimeComputedRewards;

        for (uint i = 0; i < nextDepositId; i++) {
            
            // We need to check if the Deposits overlap or if the rewards are being already computed
            bool depositsDontOverlap = allDeposits[i].enterTime > allDeposits[depositId].finishAt || allDeposits[depositId].enterTime > allDeposits[i].finishAt;
            if (depositsDontOverlap || allDeposits[depositId].finishAt == allDeposits[depositId].lastTimeComputedRewards) {
                // If the deposits don't overlap we update the weighted supply 
                totalWeightedSupplyDepositsExpired += allDeposits[i].amount * allDeposits[i].rewardsMultiplier;
            } 
            else {
                // If rewards have been computed after the analyzed deposit finishAt it means that the Deposit has already expired, we update the weighted supply 
                if (allDeposits[depositId].lastTimeComputedRewards >= allDeposits[i].finishAt) {
                    totalWeightedSupplyDepositsExpired += allDeposits[i].amount * allDeposits[i].rewardsMultiplier;
                }
                else {
                    // We have to compute the time between our Deposit lastTimeComputedRewards and the actual/end time of the analyzed Deposit
                    timePassedSinceLastTimeComputedRewards = block.timestamp.min(allDeposits[i].finishAt) - allDeposits[depositId].enterTime.max(allDeposits[depositId].lastTimeComputedRewards);

                    // We have to do a different treatment whenever we reach the Deposit itself
                    if (i != depositId) {
                        // We compute the rewards per Deposit taking into account the possible expired Deposits
                        rewardsPerDeposit += (rewardsRatePerDeposit * (timePassedSinceLastTimeComputedRewards * rewardsIssuancePerYear)) / ((weightedTotalSupply - totalWeightedSupplyDepositsExpired) * getSecondsPerYear() * MULTIPLIER);

                        // We update our Deposit lastTimeComputedRewards, this let us know (line 316) if we have reach our Deposit finishAt from another Deposit
                        allDeposits[depositId].lastTimeComputedRewards = block.timestamp.min(allDeposits[i].finishAt);

                        // If the deposit has expired we update the totalWeightedSupplyDepositsExpired
                        if (allDeposits[i].finishAt <= block.timestamp) {
                            totalWeightedSupplyDepositsExpired += allDeposits[i].amount * allDeposits[i].rewardsMultiplier;
                        }
                    }
                    else {
                        // If we haven't reach our Deposit finishAt or block.timestamp we can add the rewards
                        if (allDeposits[depositId].lastTimeComputedRewards < block.timestamp.min(allDeposits[i].finishAt)) {
                            rewardsPerDeposit += (rewardsRatePerDeposit * (timePassedSinceLastTimeComputedRewards * rewardsIssuancePerYear)) / ((weightedTotalSupply - totalWeightedSupplyDepositsExpired) * getSecondsPerYear() * MULTIPLIER);
                            allDeposits[depositId].lastTimeComputedRewards = block.timestamp.min(allDeposits[i].finishAt);
                        }
                    } 
                    
                    // Update the pending rewards of the Deposit and reset the rewardsPerDeposit variable
                    allDeposits[depositId].pendingRewards += rewardsPerDeposit;
                    rewardsPerDeposit = 0;
                }
            }
        }

        // If the deposit has already ended and wasn't marked as completed we do it (In order to don't compute again the rewards whenever the claim happens)
        if (block.timestamp >= allDeposits[depositId].finishAt && !allDeposits[depositId].completed) {
            allDeposits[depositId].completed = true;
        }
    }

    /**
     * @notice Internal function that computes the seconds per year
     */
    function getSecondsPerYear() internal pure returns (uint256) {
        return (12 * 30 * 24 * 60 * 60); // Months * Days * Hours * Minutes * Seconds
    }
}