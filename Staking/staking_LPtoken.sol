// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IRouter.sol";

contract StakingRewards is Ownable, ReentrancyGuard {
    // ============= VARIABLES ============

    address public immutable token_contract;

    // Contract address of the staked token
    IERC20 public immutable stakingToken;
    // Contract address of the LP token
    IERC20 public immutable LpToken;
    // Total staked
    uint public totalSupply;
    // The maximum amount of tokens in the staking pool
    uint public MAX_NUM_OF_TOKENS_IN_POOL;
    // APR coefficient conversion LP token/ reward token
    uint public coefficient;
    // Timestamp of when the rewards start
    uint256 public StartStakingDate;
    // deposit rewards
    uint public deposit_reward;

    // Timestamp of when the rewards finish
    uint256 public EndStakingDate;

    // User address => rewards to be claimed
    mapping(address => uint) public rewards;
    // User address => start staking date
    mapping(address => uint) public userStartStakePeriod;
    // User address => staked amount
    mapping(address => uint) public balanceOf;

    constructor(address _token_contract, address _LpToken, uint256 _MAX_NUM_OF_TOKENS_IN_POOL, uint256 _coefficient, uint256 _StartStakingDate,uint256 _periodStaking) Ownable(msg.sender) {
        token_contract=_token_contract;
        stakingToken = IERC20(token_contract);
        LpToken = IERC20(_LpToken);
        MAX_NUM_OF_TOKENS_IN_POOL = _MAX_NUM_OF_TOKENS_IN_POOL;
        coefficient=_coefficient;
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
            rewards[_account]=rewards[_account]+(balanceOf[_account]* (now_time-userStartStakePeriod[_account])*coefficient/(100*31536000));
        }
        _;
    }

    // ============= FUNCTIONS ============

    function stake( uint _amount) external checkAfterStartDate checkBeforeEndDate nonReentrant updateReward(msg.sender) {
        require(_amount > 0, "amount = 0");
        require(totalSupply + _amount <= MAX_NUM_OF_TOKENS_IN_POOL,"Maximum number of tokens staked has been reached!");
        //Each time the user stakes, the rewards won up to now are saved, and a "new" staking period starts with more tokens
        userStartStakePeriod[msg.sender]=block.timestamp;
        LpToken.transferFrom(msg.sender, address(this), _amount);
        balanceOf[msg.sender] += _amount;
        totalSupply += _amount;
    }

    function getRewardEarn(address _user) public view returns (uint256){
        uint256 now_time=block.timestamp;
        if (now_time>EndStakingDate) {
            now_time=EndStakingDate;
        }
        return rewards[_user]+(balanceOf[_user]* (now_time-userStartStakePeriod[_user])*coefficient/(100*31536000));
    }

    function WithdrawReward() external checkAfterEndDate nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        require( reward > 0,"Nothing to withdraw");
        rewards[msg.sender]=0;
        userStartStakePeriod[msg.sender]=block.timestamp;
        stakingToken.transfer(msg.sender, reward);
    }

    function claimRewardsAndWithdrawal(uint256 _quantity) external checkAfterEndDate nonReentrant updateReward(msg.sender) {
        uint256 balance_user = balanceOf[msg.sender];
        require( balance_user > 0,"Nothing to withdraw");
        require(balanceOf[msg.sender] >= _quantity, "Quantity exceeds balance!");
        uint256 reward = rewards[msg.sender];
        balanceOf[msg.sender] -= _quantity;
        rewards[msg.sender]=0;
        totalSupply -= _quantity;
        userStartStakePeriod[msg.sender]=block.timestamp;
        stakingToken.transfer(msg.sender,reward);
        LpToken.transfer(msg.sender,_quantity);
    }

    function supplyRewards(uint _amount) external onlyOwner {
        require(_amount > 0, "amount must be greater than 0");
        bool success = stakingToken.transferFrom(msg.sender,address(this),_amount);
        require(success, "transfer was not successfull");
        deposit_reward+=_amount;
    }

    function return_To_Owner(uint256 _amount)  external onlyOwner {
        require(deposit_reward>=_amount);
        deposit_reward-=_amount;
        stakingToken.transfer(msg.sender, _amount);
    }

}