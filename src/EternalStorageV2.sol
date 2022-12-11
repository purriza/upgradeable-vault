// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./EternalStorageV1.sol";

/**
 * @title EternalStorageV2
 * @dev This contract holds all the necessary state variable to manage the storage of the contract.  
 */

contract EternalStorageV2 is EternalStorageV1 {

    /// @dev Variable to store the LayerZero endpoint
    address public lzEndpoint;

}