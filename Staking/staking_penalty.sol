// SPDX-License-Identifier:MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

//Each user stakes for a specified period. 10% penalty on their deposit if they withdraw before the end of the period
contract StakingPenalty is Ownable, ReentrancyGuard {
    // ============= VARIABLES ============

    // Contract address of the staked token
    IERC20 public immutable stakingToken;
    // Total staked
    uint public totalSupply;
    // Max amount that people can stake
    uint public MIN_AMOUNT_STAKE;
    // APR yield
    uint public yield;
    // period
    uint public period;
    // acivated ?
    bool private active;
    // Fee collecting address from the "withdraw immediately"
    address public FEE_COLLECTING_WALLET;

    // User address => start staking date
    mapping(address => uint) public userStartStakePeriod;
    // User address => end staking date
    mapping(address => uint) public userEndStakePeriod;
    // User address => staked amount
    mapping(address => uint) public balanceOf;
    // User address => rewards to be claimed
    mapping(address => uint) public rewards;

    constructor(address _stakingToken, uint256 _MIN_AMOUNT_STAKE, uint256 _yield, uint256 _periodStaking, address _FEE_COLLECTING_WALLET) Ownable(msg.sender) {
        stakingToken = IERC20(_stakingToken);
        MIN_AMOUNT_STAKE = _MIN_AMOUNT_STAKE;
        yield= _yield;
        period= _periodStaking * 1 days;
        active=true;
        FEE_COLLECTING_WALLET=_FEE_COLLECTING_WALLET;
    }

    // ============= MODIFIERS ============

    modifier isActive(  ){
        require( active == true );
        _;
    }

    modifier isInactive(  ){
        require( active == false );
        _;
    }

    modifier updateReward(address _user) {

        if (_user != address(0)) {
            uint256 now_time=block.timestamp;
            if (now_time>userEndStakePeriod[_user]) {
                now_time=userEndStakePeriod[_user];
            }   
            rewards[_user]=rewards[_user]+((balanceOf[_user])* (now_time-userStartStakePeriod[_user])*yield/(100*31536000));
        }
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
    function change_minimum_stake(uint256 _minimum) onlyOwner public returns (bool) {
        MIN_AMOUNT_STAKE=_minimum;
        return true;
    }

    function changeFeeCollectingWallet(address _newWallet) public onlyOwner {
        FEE_COLLECTING_WALLET = _newWallet;
    }

    // staking
    function stake( uint _amount) external isActive updateReward(msg.sender) nonReentrant {
        require(_amount >= MIN_AMOUNT_STAKE, "Minimum amount needed");
        userStartStakePeriod[msg.sender]=block.timestamp;
        userEndStakePeriod[msg.sender]=userStartStakePeriod[msg.sender]+period;
        stakingToken.transferFrom(msg.sender, address(this), _amount);
        balanceOf[msg.sender] += _amount;
        totalSupply += _amount;
    }

    function getRewardEarn(address _user) public view returns (uint256){
        uint256 now_time=block.timestamp;
        if (now_time>userEndStakePeriod[_user]) {
            now_time=userEndStakePeriod[_user];
        }
        return balanceOf[_user]*(now_time-userStartStakePeriod[_user])*yield/(100*31536000);
    }

    function claimRewardsAndWithdrawal() external updateReward(msg.sender) nonReentrant {
        uint256 balance_user = balanceOf[msg.sender];
        require( balance_user > 0,"Nothing to withdraw");
        uint256 reward = getRewardEarn(msg.sender);
        totalSupply -= balance_user;
        //Penalty of 10% on the deposit if the user claims before the end of his staking period
        if(block.timestamp<userEndStakePeriod[msg.sender]){
            stakingToken.transfer(FEE_COLLECTING_WALLET,balance_user * 10 / 100);
            balance_user=balance_user*90/100;
        }
        uint256 _amount = balance_user + reward;
        balanceOf[msg.sender]= 0;
        stakingToken.transfer(msg.sender,_amount);
    }

    function return_To_Owner(uint256 _amount)  external onlyOwner {
        stakingToken.transfer(msg.sender, _amount);
    }

}
