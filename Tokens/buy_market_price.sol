// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./getpriceToken.sol";

contract buyMarket is Ownable, ReentrancyGuard, PriceInterface{
    // ============= VARIABLES ============

    // Contract address of the token
    IERC20 public immutable purchaseToken;

    uint256 public total_tokens_buy=0;

    bool private active;

    modifier isActive(  ){
        require( active == true );
        _;
    }

    modifier isInactive(  ){
        require( active == false );
        _;
    }

    event puchaseEvent( address indexed _buyer , uint256 _value);

    constructor(address _purchaseToken, address pairuniswap) PriceInterface(pairuniswap) Ownable(msg.sender) {
        purchaseToken = IERC20(_purchaseToken);
        active=true;
    }

    function activate() onlyOwner isInactive public returns ( bool ) {
        active = true;
        return true;
    }

    function inactivate() onlyOwner isActive public returns ( bool ) {
        active = false;
        return true;
    }

    function getActive() public view returns(bool){
        return active;
    }

    function purchase() isActive payable public returns (bool)
    {
        uint256 lastPriceToken=getTokenPrice();
        uint256 tokens=(msg.value*1e18)/lastPriceToken;

        purchaseToken.transfer(msg.sender,tokens);
        total_tokens_buy+=tokens;

        payable(owner()).transfer(msg.value);
        
        emit puchaseEvent( msg.sender, msg.value);
        return true;
    }  

    function return_To_Owner(uint256 _amount)  external onlyOwner {
        purchaseToken.transfer(msg.sender, _amount);
    }

}