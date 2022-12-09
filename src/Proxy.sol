// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

/**
 * @title Proxy 
 * @dev This contract delegates every call to a specific implementation.
 */

abstract contract Proxy {

    /**
     * @notice Function that gets the address of the last version of the implementation
     */
    function implementation() virtual public view returns (address);

    /**
     * @notice Fallback function that delegates all the calls to the implementation.
     */
    fallback () external {
        address _impl = implementation();

        assembly {
            //let _impl := sload(0) // Variable delegate

            let callDataSize := calldatasize()
            calldatacopy(0x0, 0, callDataSize)
            
            let availableGas := gas()

            let result := delegatecall(availableGas, _impl, 0x0, callDataSize, 0, 0)
            
            let returnDataSize := returndatasize()
            returndatacopy(0x0, 0, returnDataSize)

            switch result
            case 0 { 
                revert(0, 0) 
            }
            default { 
                return(0, returnDataSize) 
            }
        }
    }
}