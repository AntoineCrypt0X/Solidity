// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AirDrop is Ownable {

    // Contract address of the staked token
    IERC20 public immutable airdropToken;

    constructor(address _airdropToken) Ownable(msg.sender) {
        airdropToken = IERC20(_airdropToken);
    }

    //Airdrop a quantity of tokens to a list of addresses
    function Send_Token_from_List(address[] memory listAdress, uint256 amount) onlyOwner public returns (bool) {
        for(uint i=0;i<listAdress.length;i++){
            address address_user=listAdress[i];
            airdropToken.transfer(address_user, amount);
        }
        return true;
    }

    function return_To_Owner(uint256 _amount)  external onlyOwner {
        airdropToken.transfer(msg.sender, _amount);
    }

}