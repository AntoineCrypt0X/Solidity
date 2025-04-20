// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./bet_paramv8_2.sol";

contract ApproveDelegatorContract {
    IERC20 public immutable token = IERC20("Token address");

    constructor() {
    }

    // Function to place a bet and transfer the tokens to the child contract.
    function placeBet(address betAddress, uint256 _teamSelected, uint256 amount) public {
        // Step 1: Transfer the user's tokens to the child contract.
        bool success = token.transferFrom(msg.sender, betAddress, amount);
        require(success);

        // Step 2: Notify the child contract to record the bet.
        bettest(betAddress).betFromDelegator(msg.sender, _teamSelected, amount);
    }
}
