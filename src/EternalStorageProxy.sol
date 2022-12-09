// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./EternalStorage.sol";
import "./Proxy.sol";

/**
 * @title EternalStorageProxy
 * @dev This proxy holds the storage of the token contract and delegates every call to the implementation set
 */
contract EternalStorageProxy is EternalStorage, Proxy {

    address public delegate; // TO-DO Possible to be internal? public for the tests

    constructor(address _delegate) {
        owner = msg.sender;
        delegate = _delegate;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    /**
     * @notice This function allows to transfer the ownership of the proxy
     * @param newOwner New owner address
     */
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Address 0 detected");

        owner = newOwner;
    }

    /**
     * @notice Function that returns the address of the last version of the implementation
     */
    function implementation() public override view returns (address) {
        return delegate;
    }

    /**
     * @notice This function allows to change the delegate address 
     * @param newDelegateAddress New delegate address
     */
    function upgradeDelegate(address newDelegateAddress) public onlyOwner {
        require(newDelegateAddress != address(0), "Address 0 detected");

        delegate = newDelegateAddress;
    }

}