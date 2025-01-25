// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IRouter.sol";

contract StakingRewards is Ownable, ReentrancyGuard {
    // ============= VARIABLES ============
    
    // Contract address of the token used for staking
    address public immutable token_contract;

    // Interface of the token used for staking
    IERC20 public immutable stakingToken;
    // Total staked
    uint public totalSupply;
    // The maximum amount of tokens in the staking pool
    uint public MAX_NUM_OF_TOKENS_IN_POOL;
    // APR yield
    uint public yield;
    // The timestamp when the reward period starts
    uint256 public StartStakingDate;
    // The timestamp when the reward period ends
    uint256 public EndStakingDate;
    // deposit rewards
    uint public deposit_reward;

    // User address => rewards to be claimed
    mapping(address => uint) public rewards;
    // User address => start staking date
    mapping(address => uint) public userStartStakePeriod;
    // User address => staked amount
    mapping(address => uint) public balanceOf;

    constructor(address _token_contract, uint256 _MAX_NUM_OF_TOKENS_IN_POOL, uint256 _yield, uint256 _StartStakingDate, uint256 _periodStaking) Ownable(msg.sender) {
        token_contract = _token_contract;
        stakingToken = IERC20(token_contract);
        MAX_NUM_OF_TOKENS_IN_POOL = _MAX_NUM_OF_TOKENS_IN_POOL;
        yield = _yield;
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
            rewards[_account] = rewards[_account] + (balanceOf[_account] * (now_time-userStartStakePeriod[_account]) * yield / (100 * 31536000));
        }
        _;
    }

    // ============= FUNCTIONS ============

    function stake( uint _amount) external checkAfterStartDate checkBeforeEndDate nonReentrant updateReward(msg.sender) {
        require(_amount > 0, "amount = 0");
        require(totalSupply + _amount <= MAX_NUM_OF_TOKENS_IN_POOL, "Maximum number of tokens staked has been reached!");
        // Each time the user stakes, the rewards won up to now are saved, and a new staking period starts with more tokens
        userStartStakePeriod[msg.sender] = block.timestamp;
        stakingToken.transferFrom(msg.sender, address(this), _amount);
        balanceOf[msg.sender] += _amount;
        totalSupply += _amount;
    }

    // Tokens are bought through the Uniswap router and sent to the contract. Slippage is on a base of 1000 (ex: 0.5% = 5/1000).
    function stakeWithETH(address _uniswapRouter, uint slippage) external payable checkAfterStartDate checkBeforeEndDate nonReentrant updateReward(msg.sender) {
        require(msg.value > 0, "Must send ETH to buy token");
        IUniswapV2Router router = IUniswapV2Router(_uniswapRouter);
        uint deadline = block.timestamp + 300;
        uint amountOutMin = getEstimatedTokensForETH(msg.value,_uniswapRouter)[1] * (1000 - slippage)) / 1000;
        uint256 _amount=amountOutMin;
        require(totalSupply + _amount <= MAX_NUM_OF_TOKENS_IN_POOL, "Maximum number of tokens staked has been reached!");

        address[] memory path = new address[](2);
        path[0] = router.WETH(); 
        path[1] = token_contract;        

        router.swapExactETHForTokens{ value: msg.value }(
            _amount, 
            path,         
            address(this),   
            deadline      
        );

        // Each time the user stakes, the rewards won up to now are saved, and a new staking period starts with more tokens
        userStartStakePeriod[msg.sender] = block.timestamp;
        balanceOf[msg.sender] += _amount;
        totalSupply += _amount;
    }

    function getEstimatedTokensForETH(uint amountIn, address _uniswapRouter) internal view returns (uint[] memory amounts) {
        IUniswapV2Router router = IUniswapV2Router(_uniswapRouter);

        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = token_contract; 

        return router.getAmountsOut(amountIn, path);
    }

    function getRewardEarn(address _user) public view returns (uint256){
        uint256 now_time = block.timestamp;
        if (now_time > EndStakingDate) {
            now_time = EndStakingDate;
        }
        return rewards[_user] + (balanceOf[_user] * (now_time-userStartStakePeriod[_user]) * yield / (100 * 31536000));
    }

    function WithdrawReward() external checkAfterEndDate nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        require( reward > 0, "Nothing to withdraw");
        rewards[msg.sender]=0;
        userStartStakePeriod[msg.sender]=block.timestamp;
        stakingToken.transfer(msg.sender, reward);
    }

    function claimRewardsAndWithdrawal(uint256 _quantity) external checkAfterEndDate nonReentrant updateReward(msg.sender) {
        uint256 balance_user = balanceOf[msg.sender];
        require( balance_user > 0, "Nothing to withdraw");
        require(balanceOf[msg.sender] >= _quantity, "Quantity exceeds balance!");
        uint256 reward = rewards[msg.sender];
        uint256 _amount = _quantity + reward;
        balanceOf[msg.sender] -= _quantity;
        rewards[msg.sender] = 0;
        totalSupply -= _quantity;
        userStartStakePeriod[msg.sender] = block.timestamp;
        stakingToken.transfer(msg.sender, _amount);
    }

    function supplyRewards(uint _amount) external onlyOwner {
        require(_amount > 0, "amount must be greater than 0");
        bool success = stakingToken.transferFrom(msg.sender, address(this), _amount);
        require(success, "transfer was not successfull");
        deposit_reward += _amount;
    }

    // The Owner has access only to the reward he deposits
    function return_To_Owner(uint256 _amount)  external onlyOwner {
        require(deposit_reward >= _amount);
        deposit_reward -= _amount;
        stakingToken.transfer(msg.sender, _amount);
    }

}
