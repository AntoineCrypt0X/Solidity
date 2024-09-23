// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract StakingRewards is Ownable, ReentrancyGuard {
    // ============= VARIABLES ============

    // Contract address of the staked token
    IERC20 public immutable stakingToken;
    // Total staked
    uint public totalSupply;
    // Max amount that people can stake
    uint public MAX_AMOUNT_STAKE;
    // The maximum amount of tokens in the staking pool
    uint public MAX_NUM_OF_TOKENS_IN_POOL;
    // APR yield
    uint public yield;
    // Timestamp of when the rewards start
    uint256 public StartStakingDate;

    // Timestamp of when the rewards finish
    uint256 public EndStakingDate;

    // User address => rewards to be claimed
    mapping(address => uint) public rewards;
    // User address => start staking date
    mapping(address => uint) public userStartStakePeriod;
    // User address => staked amount
    mapping(address => uint) public balanceOf;

    constructor(address _stakingToken, uint256 _MAX_AMOUNT_STAKE,uint256 _MAX_NUM_OF_TOKENS_IN_POOL, uint256 _yield, uint256 _StartStakingDate,uint256 _periodStaking) Ownable(msg.sender) {
        stakingToken = IERC20(_stakingToken);
        MAX_AMOUNT_STAKE = _MAX_AMOUNT_STAKE;
        MAX_NUM_OF_TOKENS_IN_POOL = _MAX_NUM_OF_TOKENS_IN_POOL;
        yield=_yield;
        StartStakingDate=_StartStakingDate;
        EndStakingDate=StartStakingDate + (_periodStaking * 1 days);
    }

    // ============= MODIFIERS ============

    modifier checkBeforeEndDate {
      _ ;
      require ( block.timestamp < EndStakingDate) ;
    }

    modifier checkAfterStartDate {
      _ ;
      require ( block.timestamp > StartStakingDate) ;
    }

    modifier checkAfterEndDate {
      _ ;
      require ( block.timestamp > EndStakingDate) ;
    }

    modifier updateReward(address _account) {

        if (_account != address(0)) {
            uint256 now_time=block.timestamp;
            if (now_time>EndStakingDate) {
                now_time=EndStakingDate;
            }
            rewards[_account]=rewards[_account]+(balanceOf[_account]* (now_time-userStartStakePeriod[_account])*yield/(100*31536000));
        }
        _;
    }

    // ============= FUNCTIONS ============

    function stake( uint _amount) external checkAfterStartDate checkBeforeEndDate nonReentrant updateReward(msg.sender) {
        require(_amount > 0, "amount = 0");
        require(balanceOf[msg.sender] + _amount <= MAX_AMOUNT_STAKE,"Too much staked!");
        require(totalSupply + _amount <= MAX_NUM_OF_TOKENS_IN_POOL,"Maximum number of tokens staked has been reached!");
        //Each time the user stakes, the rewards won up to now are saved, and a "new" staking period starts with more tokens
        userStartStakePeriod[msg.sender]=block.timestamp;
        stakingToken.transferFrom(msg.sender, address(this), _amount);
        balanceOf[msg.sender] += _amount;
        totalSupply += _amount;
    }

    function getRewardEarn(address _user) public view returns (uint256){
        uint256 now_time=block.timestamp;
        if (now_time>EndStakingDate) {
            now_time=EndStakingDate;
        }
        return rewards[_user]+(balanceOf[_user]* (now_time-userStartStakePeriod[_user])*yield/(100*31536000));
    }

    function claimRewardsAndWithdrawal() external checkAfterEndDate nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        uint256 balance_user = balanceOf[msg.sender];
        require( balance_user > 0,"Nothing to withdraw");
        uint256 _amount = balance_user + reward;
        balanceOf[msg.sender]= 0;
        rewards[msg.sender]=0;
        totalSupply -= balance_user;
        stakingToken.transfer(msg.sender,_amount);
    }

    function return_To_Owner(uint256 _amount)  external onlyOwner {
        stakingToken.transfer(msg.sender, _amount);
    }

}
