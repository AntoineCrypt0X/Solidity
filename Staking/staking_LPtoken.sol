// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IRouter.sol";

// Users stake LP tokens, get a specific token as reward
contract StakingRewards is Ownable, ReentrancyGuard {
    // ============= VARIABLES ============

    // Interface of the reward token
    IERC20 public immutable rewardToken;
    // Interface of the LP token
    IERC20 public immutable lpToken;
    // Total staked
    uint public totalSupply;
    // The maximum amount of tokens in the staking pool
    uint public MAX_NUM_OF_TOKENS_IN_POOL;
    // APR coefficient conversion LP token/ reward token, on a base of 100
    uint public coefficient;
    // The timestamp when the reward period starts
    uint256 public StartStakingDate;
    // The timestamp when the reward period ends
    uint256 public EndStakingDate;
    // Owner deposit rewards
    uint256 public deposit_reward;

    // User address => rewards to be claimed
    mapping(address => uint) public rewards;
    // User address => start staking date
    mapping(address => uint) public userStartStakePeriod;
    // User address => staked amount
    mapping(address => uint) public balanceOf;

    constructor(address _rewardToken, address _lpToken, uint256 _MAX_NUM_OF_TOKENS_IN_POOL, uint256 _coefficient, uint256 _StartStakingDate, uint256 _periodStaking) Ownable(msg.sender) {
        rewardToken = IERC20(_rewardToken);
        lpToken = IERC20(_lpToken);
        MAX_NUM_OF_TOKENS_IN_POOL = _MAX_NUM_OF_TOKENS_IN_POOL;
        coefficient = _coefficient;
        StartStakingDate = _StartStakingDate;
        EndStakingDate = StartStakingDate + (_periodStaking * 1 days);
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
            uint256 now_time = block.timestamp;
            if (now_time > EndStakingDate) {
                now_time = EndStakingDate;
            }
            rewards[_account] = rewards[_account] + (balanceOf[_account] * (now_time-userStartStakePeriod[_account]) * coefficient / (100 * 31536000));
        }
        _;
    }

    // ============= FUNCTIONS ============

    function stake( uint _amount) external checkAfterStartDate checkBeforeEndDate nonReentrant updateReward(msg.sender) {
        require(_amount > 0, "amount = 0");
        require(totalSupply + _amount <= MAX_NUM_OF_TOKENS_IN_POOL,"Maximum number of tokens staked has been reached!");
        // Each time the user stakes, the rewards won up to now are saved, and a new staking period starts with more tokens
        userStartStakePeriod[msg.sender] = block.timestamp;
        lpToken.transferFrom(msg.sender, address(this), _amount);
        balanceOf[msg.sender] += _amount;
        totalSupply += _amount;
    }

    function getRewardEarn(address _user) public view returns (uint256){
        uint256 now_time = block.timestamp;
        if (now_time > EndStakingDate) {
            now_time = EndStakingDate;
        }
        return rewards[_user] + (balanceOf[_user] * (now_time-userStartStakePeriod[_user]) * coefficient / (100 * 31536000));
    }

    function WithdrawReward() external checkAfterEndDate nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        require( reward > 0,"Nothing to withdraw");
        rewards[msg.sender] = 0;
        // Staking is reinitialized
        userStartStakePeriod[msg.sender] = block.timestamp;
        rewardToken.transfer(msg.sender, reward);
    }

    function claimRewardsAndWithdrawal(uint256 _quantity) external checkAfterEndDate nonReentrant updateReward(msg.sender) {
        uint256 balance_user = balanceOf[msg.sender];
        require( balance_user > 0,"Nothing to withdraw");
        require(balanceOf[msg.sender] >= _quantity, "Quantity exceeds balance!");
        uint256 reward = rewards[msg.sender];
        balanceOf[msg.sender] -= _quantity;
        rewards[msg.sender] = 0;
        totalSupply -= _quantity;
        // A new staking period starts with the new balance of tokens
        userStartStakePeriod[msg.sender] = block.timestamp;
        rewardToken.transfer(msg.sender, reward);
        lpToken.transfer(msg.sender, _quantity);
    }

    function supplyRewards(uint256 _amount) external onlyOwner {
        require(_amount > 0, "amount must be greater than 0");
        bool success = rewardToken.transferFrom(msg.sender,address(this), _amount);
        require(success, "transfer was not successfull");
        deposit_reward += _amount;
    }

    // The Owner has access only to the reward he deposits
    function return_To_Owner(uint256 _amount)  external onlyOwner {
        require(deposit_reward >= _amount);
        deposit_reward -= _amount;
        rewardToken.transfer(msg.sender, _amount);
    }

}
