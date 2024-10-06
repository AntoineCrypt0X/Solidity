// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

//Users send to the smart contract the old token and receive a certain amount of the new token according to a coefficient
contract AirDrop is Ownable {

    // Contract address of the old token
    IERC20 public immutable oldToken;

    // Contract address of the new token
    IERC20 public immutable newToken;

    uint256 public coefficient;

    constructor(address _oldToken, address _newToken, uint256 _coefficient) Ownable(msg.sender) {
        oldToken = IERC20(_oldToken);
        newToken = IERC20(_newToken);
        coefficient=_coefficient;
    }

    function fork(uint256 amount) public returns (bool) {
        oldToken.transferFrom(msg.sender, address(this), amount);
        newToken.transfer(msg.sender,amount*coefficient);
        return true;
    }

    function return_To_Owner(IERC20 token, uint256 _amount)  external onlyOwner {
        token.transfer(msg.sender, _amount);
    }

}
