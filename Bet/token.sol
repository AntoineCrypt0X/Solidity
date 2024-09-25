// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token20 is ERC20 {
    constructor(uint256 initialSupply) ERC20("Token name", "Ticker") {
        _mint(msg.sender, initialSupply);
    }

    function burn(uint256 value) external {
        _burn(msg.sender, value);
    }
}