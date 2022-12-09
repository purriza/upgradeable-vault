// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@layerzero-labs/contracts/token/oft/OFT.sol";

contract OmniToken is OFT {

    constructor(address _lzEndpoint) OFT("OmniToken", "OMT", _lzEndpoint) {
       _mint(msg.sender, type(uint256).max);
    }

}