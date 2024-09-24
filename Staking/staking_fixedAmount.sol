// SPDX-License-Identifier:MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Staking is Ownable, ReentrancyGuard {
    // ============= VARIABLES ============

    // Contract address of the staked token
    IERC20 public immutable stakingToken;
    // Total staked
    uint public totalSupply;
    //fixed amount that people can stake
    uint public AMOUNT_STAKE;
    // APR yield
    uint public yield;
    // duration
    uint public period;
    // staking status
    bool private active;

    // User address => start staking date
    mapping(address => uint) public userStartStakePeriod;
    // User address => end staking date
    mapping(address => uint) public userEndStakePeriod;
    // User address => staked amount
    mapping(address => uint) public balanceOf;

    constructor(address _stakingToken, uint256 _AMOUNT_STAKE, uint256 _yield, uint256 _periodStaking) Ownable(msg.sender) {
        stakingToken = IERC20(_stakingToken);
        AMOUNT_STAKE = _AMOUNT_STAKE;
        yield=_yield;
        period= _periodStaking * 1 days;
        active=true;
    }

    // ============= MODIFIERS ============

    modifier checkDateUser(address _account) {
      require ( block.timestamp > userEndStakePeriod[_account]) ;
       _ ;
    }

    modifier isActive(  ){
        require( active == true );
        _;
    }

    modifier isInactive(  ){
        require( active == false );
        _;
    }

    // ============= FUNCTIONS ============

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

    // change minimum entry
    function change_amount_stake(uint256 _newValue) onlyOwner public returns (bool) {
        AMOUNT_STAKE=_newValue;
        return true;
    }

    // staking
    function stake() external isActive nonReentrant {
        require(balanceOf[msg.sender] == 0,"You can stake only once");
        userStartStakePeriod[msg.sender]=block.timestamp;
        userEndStakePeriod[msg.sender]=userStartStakePeriod[msg.sender]+period;
        stakingToken.transferFrom(msg.sender, address(this), AMOUNT_STAKE);
        balanceOf[msg.sender] += AMOUNT_STAKE;
        totalSupply += AMOUNT_STAKE;
    }

    function getRewardEarn(address _user) public view returns (uint256){
        uint256 now_time=block.timestamp;
        if (now_time>userEndStakePeriod[_user]) {
            now_time=userEndStakePeriod[_user];
        }
        return balanceOf[_user]*(now_time-userStartStakePeriod[_user])*yield/(100*31536000);
    }

    function claimRewardsAndWithdrawal() external nonReentrant checkDateUser(msg.sender) {
        uint256 balance_user = balanceOf[msg.sender];
        require( balance_user > 0,"Nothing to withdraw");
        uint256 reward = getRewardEarn(msg.sender);
        uint256 _amount = balance_user + reward;
        balanceOf[msg.sender]= 0;
        totalSupply -= balance_user;
        stakingToken.transfer(msg.sender,_amount);
    }

    function return_To_Owner(uint256 _amount)  external onlyOwner {
        stakingToken.transfer(msg.sender, _amount);
    }

}
