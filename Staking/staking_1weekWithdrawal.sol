// SPDX-License-Identifier:MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

//Staking with a grace period of 1 week for the claim. 10% of penalty if the users withdraw immediately
contract StakingPenalty is Ownable, ReentrancyGuard {
    // ============= VARIABLES ============

    // Contract address of the staked token
    IERC20 public immutable stakingToken;
    // Total staked
    uint public totalSupply;
    // The maximum amount of tokens in the staking pool
    uint public MAX_NUM_OF_TOKENS_IN_POOL;
    // APR yield
    uint public yield;
    // date until which rewards will be distributed
    uint public MAX_DATE_REWARD_PERIOD;
    // acivated ?
    bool private active;
    // Fee collecting address from the "withdraw immediately"
    address public FEE_COLLECTING_WALLET;
    // Grace period duration for handling withdrawals
    uint public GRACE_PERIOD;
    // deposit rewards
    uint public deposit_reward;

    // User address => start staking date
    mapping(address => uint) public userStartStakePeriod;
    // User address => staked amount
    mapping(address => uint) public balanceOf;
    // User address => rewards to be claimed
    mapping(address => uint) public rewards;
    // User address => timestamp when the withdrawal has been initiated
    mapping(address => uint) public withdrawalInitiated;

    constructor(address _stakingToken, uint _MAX_NUM_OF_TOKENS_IN_POOL, uint _yield, address _FEE_COLLECTING_WALLET) Ownable(msg.sender) {
        stakingToken = IERC20(_stakingToken);
        MAX_NUM_OF_TOKENS_IN_POOL = _MAX_NUM_OF_TOKENS_IN_POOL;
        yield= _yield;
        GRACE_PERIOD = 604800; // 604 800 seconds = 1 week
        FEE_COLLECTING_WALLET=_FEE_COLLECTING_WALLET;
        MAX_DATE_REWARD_PERIOD=block.timestamp + 730 days; // 2 years
        active=true;
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

    modifier checkDateRewardPeriod() {
      require ( block.timestamp < MAX_DATE_REWARD_PERIOD) ;
       _ ;
    }

    modifier updateReward(address _user) {
        if (_user != address(0)) {
            uint256 now_time=block.timestamp;
            if (now_time>MAX_DATE_REWARD_PERIOD) {
                now_time=MAX_DATE_REWARD_PERIOD;
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

    // change maximum staked
    function change_max_stake(uint256 _max) onlyOwner public returns (bool) {
        MAX_NUM_OF_TOKENS_IN_POOL=_max;
        return true;
    }

    function changeFeeCollectingWallet(address _newWallet) public onlyOwner {
        FEE_COLLECTING_WALLET = _newWallet;
    }

    // staking
    function stake( uint _amount) external isActive updateReward(msg.sender) nonReentrant checkDateRewardPeriod {
        require(totalSupply + _amount <= MAX_NUM_OF_TOKENS_IN_POOL,"Maximum number of tokens staked has been reached!");
        userStartStakePeriod[msg.sender]=block.timestamp;
        stakingToken.transferFrom(msg.sender, address(this), _amount);
        balanceOf[msg.sender] += _amount;
        totalSupply += _amount;
    }

    function initializeWithdrawal() external nonReentrant
    {
        require(balanceOf[msg.sender] > 0, "Nothing to withdraw");
        require(withdrawalInitiated[msg.sender] == 0,"Withdrawal already initiated");
        withdrawalInitiated[msg.sender] = block.timestamp;
    }

    function getRewardEarn(address _user) public view returns (uint256){
        uint256 now_time=block.timestamp;
        if (now_time>MAX_DATE_REWARD_PERIOD) {
            now_time=MAX_DATE_REWARD_PERIOD;
        } 
        return rewards[_user]+ (balanceOf[_user]*(now_time-userStartStakePeriod[_user])*yield/(100*31536000));
    }

    function claimRewardsAndWithdrawal() external updateReward(msg.sender) nonReentrant {
        require(withdrawalInitiated[msg.sender] > 0,"Withdrawal not initiated");
        require(block.timestamp >= withdrawalInitiated[msg.sender] + GRACE_PERIOD,"Grace period not yet passed");
        uint256 balance_user = balanceOf[msg.sender];
        uint256 reward = rewards[msg.sender];
        uint256 _amount = balance_user + reward;
        balanceOf[msg.sender]= 0;
        withdrawalInitiated[msg.sender] = 0;
        totalSupply -= balance_user;
        stakingToken.transfer(msg.sender,_amount);
    }

    function withdrawImmediately() external updateReward(msg.sender) nonReentrant {
        require(withdrawalInitiated[msg.sender] > 0,"Withdrawal not initiated");
        uint256 balance_user = balanceOf[msg.sender];
        uint256 reward = rewards[msg.sender];
        uint256 _amount = (balance_user * 90 /100) + reward;
        balanceOf[msg.sender]= 0;
        withdrawalInitiated[msg.sender] = 0;
        totalSupply -= balance_user;
        //Penalty of 10% on the deposit if the user claims before the grace period
        stakingToken.transfer(FEE_COLLECTING_WALLET,balance_user * 10 / 100);
        stakingToken.transfer(msg.sender,_amount);
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
