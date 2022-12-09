THE PROJECT

This solution implements a Vault that accepts deposits of Uniswap LP tokens and locks them for a period. The user gets rewards in the form of Tokens for the deposited LP tokens. The rewards are distributed proportionally amongst the LP depositors based on their deposits. Users can claim their pending rewards at any time. 

Depending on the period that the LP tokens were locked, there is a multiplier for the rewards the user gets. The longer the LPs are locked, the bigger the multiplier for the rewards:

  Locking Period   Rewards multiplier 

    6 months             1x 
    1 year               2x 
    2 years              4x 
    4 years              8x 

Depositors can come into the Vault at any time they want and there's no limit of deposits per address. 
The rewards are given in the form of a custom Token that implements the Layer Zero Omnichain OFT20 functionality. This functionality allows the token to be transferred from and to other chains, as long as the smart contracts are deployed in both chains.

This vault is under an upgradeability proxy and uses the Eternal Storage pattern.
The project has been implemented using the Foundry Framework for deployment and testing, using solidity version 0.8.16. The code has been commented utilizing the NatSpec Format.

THE SOLUTION

This approach it's mainly based on to storing and computing information about every Interval.
An Interval it's defined as a struct that stores initialDate, finalDate, totalSupply and deposits that belong to the Interval. Whenever a Deposit it's added to the Vault this solution computes and compares all the existing Intervals in order to check if the Deposit should be part of some of the existing ones and/or if its needed to create new Intervals.

In this way, whenever a user wants to claim their pending rewards (that are attached to a Deposit), the Vault checks every single Interval to which this Deposit belongs and computes the rewards generated according to the following data:

    - The amount that this Deposit has contributed to the Interval.
    - The total supply of the Interval.
    - The time that the Deposit has been part of the Interval.
    - The fixed rate of rewards per second of the Vault.

