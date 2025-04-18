// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./token.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IDatabase_stats.sol";
import "./IRouter.sol";
import "./IBet.sol";


// Betting contract. Users bet on one or more proposed outcomes, called "pools". Users who bet on the winning pool share the 'losing pool' in proportion to their share of the winning pool.
// Double verification required to set the bet result. One by the smart contract owner and one by a validator.
contract bettest is IBet, Ownable, ReentrancyGuard {
    // ============= VARIABLES ============

    // Database statistics interface
    IDatabaseStat public immutable db;
    // Approve Delegator contract used to bypass the approve function for each bet
    address public approveDelegator;
    // Smart Contract address of the betting token
    Token20 public immutable myToken = Token20(0x692263bB7e160F3F2682c865A35EA553915f6869);
    
    //Minimum bet
    uint256 public minimumBet;
    //commission reward burnt
    uint256 public percentageBurn;
    //commission charity
    uint256 public percentageCharity;
    //commission reward to ecosystem
    uint256 public percentageEcosystem;
    //Ecosystem wallet
    address public walletEcosystem;
    //charity wallet
    address public walletCharity;
    // Validators' wallets"
    address[] public validators;
    // Bet title
    string public title;
    // Bet description
    string public description;
    // Timestamp for when the betting period starts
    uint256 public startDate;
    // Timestamp for when the betting period ends
    uint256 public endDate;
    // Number of pools (i.e., outcomes of the bet)
    uint256 public numberPools;
    // Number of tokens added to pool for rewards by the owner
    uint256 public increasePoolRewards;

    // Pool details
    struct Pool {
        string name;
        uint256 totalamountBet;
        uint256 nbParticipants;
    }

    mapping(uint256 => Pool) public poolInfo;

    // User details
    struct DataUser {
        string poolName;
        uint256 tokensBet;
    }

    mapping(address=> mapping(uint256 => uint256)) public user_pool_bet;

    // Mapping user -> rewards earned
    mapping(address=> uint256) public user_rewards_claimed;
    // Mapping user -> rewards earned
    mapping(address=> bool) public user_claimed;
    // Total tokens bet
    uint256 public totalBet;
    // Total number of participants
    uint256 public totalParticipants;
    // Bet status
    string public betStatus;
    // Pool preset winner
    uint256 public preset_poolWinner;
    // Wallet that makes the pre-set result
    address public preset_wallet;
    // Pool winner
    uint256 public poolWinner;

    event Bet(address indexed  user, uint256 _poolSelected, uint256 amount);
    event Claim(address indexed  user, uint256 amount);
    event Cancel();
    event GetReimbursement(address indexed  user, uint256 amount);
    event PresetWinner(uint256 winner);
    event ValidateWinner(uint256 winner);
    event RenounceWinner(uint256 winner);

    constructor(address _owner, address _db, address _approveDelegator, uint256 _minimumBet, uint256[] memory _commissions, address[] memory _wallets, uint256 _numberPools, string[] memory _poolName, string[] memory _betDescription, uint256 _endDate, address[] memory _validators) Ownable(_owner) {
        require(_numberPools >= 2);
        require(_poolName.length == _numberPools);
        require(_betDescription.length == 2);
        require(_commissions.length == 3);
        require(_wallets.length == 2);
        require(_validators.length > 0);
        require(_minimumBet > 0);
        for (uint256 i = 0; i < _validators.length; i++) {
            require(_validators[i] != owner());
        }

        db = IDatabaseStat(_db);
        approveDelegator = _approveDelegator;
        minimumBet = _minimumBet;

        //Commissions
        percentageBurn = _commissions[0];
        percentageCharity = _commissions[1];
        percentageEcosystem = _commissions[2];

        // Wallets
        walletEcosystem = _wallets[0];
        walletCharity = _wallets[1];
        numberPools = _numberPools;

        for(uint256 j = 0; j < _poolName.length; j++){
            poolInfo[j+1].name = _poolName[j];
        }

        title = _betDescription[0];
        description = _betDescription[1];
        startDate = block.timestamp;
        betStatus = "open";
        require(_endDate > startDate);
        endDate = _endDate;
        validators = _validators;
    }

    // ============= MODIFIERS ============

    modifier checkBeforeEndDate {
      require ( block.timestamp < endDate) ;
      _ ;
    }

    modifier checkAfterEndDate {
      require ( block.timestamp > endDate) ;
      _ ;
    }

    modifier checkStatus(string memory _status) {
      require(keccak256(abi.encodePacked((betStatus))) == keccak256(abi.encodePacked(_status)));
      _ ;
    }

    modifier checkNotStatus(string memory _status) {
      require(keccak256(abi.encodePacked((betStatus))) != keccak256(abi.encodePacked(_status)));
      _ ;
    }

    // ============= FUNCTIONS ============

    // The owner adds tokens to pools to increase participant rewards
    function increase_Pool_Rewards(uint256 _nbTokens) onlyOwner external  {

        for(uint256 i = 1; i <= numberPools; i++){
            poolInfo[i].totalamountBet = _nbTokens;
        }
        increasePoolRewards += _nbTokens * numberPools;
        totalBet += increasePoolRewards;
        bool success = myToken.transferFrom(msg.sender, address(this), _nbTokens * numberPools);
        require(success);
    }

    // The owner can only access the additional rewards they have deposited in the pools through the 'increase_Pool_Rewards' function. This function will be triggered if the bet is canceled.
    function return_Rewards_To_Owner() checkStatus ("cancelled") external onlyOwner {
        require(increasePoolRewards > 0);
        totalBet -= increasePoolRewards;
        bool success = myToken.transfer(msg.sender, increasePoolRewards);
        require(success);
        increasePoolRewards = 0;
    }

    function bet(uint256 _poolSelected, uint256 numberTokens) nonReentrant checkNotStatus("cancelled") checkBeforeEndDate external  {
        require(_poolSelected >= 1 && _poolSelected <= numberPools, "invalid team selected");
        require(numberTokens >= minimumBet, "invalid token sent");
        db.updateContractsUser(msg.sender);

        if(user_pool_bet[msg.sender][_poolSelected] == 0){
            poolInfo[_poolSelected].nbParticipants += 1;
        }

        uint256 currentBetUser = getUserTotalBet(msg.sender);

        if(currentBetUser == 0){
            totalParticipants += 1;
            db.modifyUserBets(msg.sender);
            db.AddActiveContract(msg.sender, address(this));
        }

        bool success = myToken.transferFrom(msg.sender, address(this), numberTokens);
        require(success);
        user_pool_bet[msg.sender][_poolSelected] += numberTokens;
        poolInfo[_poolSelected].totalamountBet += numberTokens;
        totalBet += numberTokens;

        emit Bet(msg.sender, _poolSelected, numberTokens);
    }

    function betFromDelegator(address _user, uint256 _poolSelected, uint256 numberTokens) nonReentrant checkNotStatus("cancelled") checkBeforeEndDate external  {
        require(msg.sender == approveDelegator, "Only delegator contract can call this");
        require(_poolSelected >= 1 && _poolSelected <= numberPools, "invalid team selected");
        require(numberTokens >= minimumBet, "invalid token sent");
        db.updateContractsUser(_user);

        if(user_pool_bet[_user][_poolSelected] == 0){
            poolInfo[_poolSelected].nbParticipants += 1;
        }

        uint256 currentBetUser = getUserTotalBet(_user);

        if(currentBetUser == 0){
            totalParticipants += 1;
            db.modifyUserBets(_user);
            db.AddActiveContract(_user, address(this));
        }

        user_pool_bet[_user][_poolSelected] += numberTokens;
        poolInfo[_poolSelected].totalamountBet += numberTokens;
        totalBet += numberTokens;

        emit Bet(_user, _poolSelected, numberTokens);
    }

    // Place bets with ETH. Tokens are bought through the Uniswap router and sent to the contract. Slippage is on a base of 1000 (ex: 0.5% = 5/1000).
    function betWithETH(uint256 _poolSelected, address _uniswapRouter, uint256 slippage) nonReentrant checkNotStatus("cancelled") checkBeforeEndDate payable external  {
        require(_poolSelected >= 1 && _poolSelected <= numberPools, "invalid team selected");
        require(msg.value > 0);
        db.updateContractsUser(msg.sender);

        IUniswapV2Router router = IUniswapV2Router(_uniswapRouter);
        uint deadline = block.timestamp + 300;
        uint amountOutMin = (getEstimatedTokensForETH(msg.value, _uniswapRouter)[1] * (1000 - slippage)) / 1000;
        uint256 numberTokens = amountOutMin;
        require(numberTokens >= minimumBet, "Minimum bet not met");

        address[] memory path = new address[](2);
        path[0] = router.WETH(); 
        path[1] = address(myToken);        

        router.swapExactETHForTokens{ value: msg.value }(
            numberTokens, 
            path,         
            address(this),   
            deadline      
        );
        
        if(user_pool_bet[msg.sender][_poolSelected] == 0){
            poolInfo[_poolSelected].nbParticipants += 1;
        }

        uint256 currentBetUser = getUserTotalBet(msg.sender);

        if(currentBetUser == 0){
            totalParticipants += 1;
            db.modifyUserBets(msg.sender);
            db.AddActiveContract(msg.sender, address(this));
        }

        user_pool_bet[msg.sender][_poolSelected] += numberTokens;
        poolInfo[_poolSelected].totalamountBet += numberTokens;
        totalBet += numberTokens;

        emit Bet(msg.sender, _poolSelected, numberTokens);  
    }

    function getEstimatedTokensForETH(uint256 amountIn, address _uniswapRouter) internal view returns (uint[] memory amounts) {
        IUniswapV2Router router = IUniswapV2Router(_uniswapRouter);

        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = address(myToken); 

        return router.getAmountsOut(amountIn, path);
    }

    function isOver() external view returns (bool) {
        return (block.timestamp > endDate);
    }

    function addValidator(address newAddress) onlyOwner external  {
        require(newAddress != owner(), "Owner cannot be a validator");
        require(preset_poolWinner == 0);
        validators.push(newAddress);
    }

    function removeValidator(uint256 index) onlyOwner external {
        require(index < validators.length);
        require(preset_poolWinner == 0);
        
        // Move the last element into the place to delete
        validators[index] = validators[validators.length - 1];
        // Remove the last element
        validators.pop();

        require(validators.length > 0);
        if(validators.length == 1){
            require(validators[0] != owner(), "The last validator can't be the owner"); // Can happen when the transferOwnership function is triggered
        }
    }

    // Result pre-set by the Owner
    function pre_set_winner(uint256 _poolWinner) checkNotStatus("claim") checkNotStatus("cancelled") onlyOwner checkAfterEndDate public {
        require(_poolWinner >= 1 && _poolWinner <= numberPools, "Invalid pool");
        preset_poolWinner  = _poolWinner;
        preset_wallet = msg.sender;
        emit PresetWinner(_poolWinner);
    }

    function isValidator(address _address) public view returns (bool) {
        for (uint256 i = 0; i < validators.length; i++) {
            if (validators[i] == _address) {
                return true;
            }
        }
        return false;
    }

    function getValidators() external view returns (address[] memory) {
        return  validators;
    }
    
    // Only by a validator
    function set_winner(uint256 _poolWinner) checkNotStatus("claim") checkNotStatus("cancelled") checkAfterEndDate public {
        require(preset_poolWinner != 0, "Winner not preset yet");
        require(msg.sender != preset_wallet);
        require(isValidator(msg.sender), "You are not a validator");
        require(_poolWinner >= 1 && _poolWinner <= numberPools);
        
        if(_poolWinner == preset_poolWinner){
            if(poolInfo[_poolWinner].totalamountBet == 0){
                betStatus = "cancelled";
                emit Cancel();
            }
            else{
                poolWinner = _poolWinner;
                betStatus = "claim";
                uint256 _contractBalance = myToken.balanceOf(address(this));
                if(_contractBalance > totalBet){
                    totalBet = _contractBalance;
                }
                // Additional rewards deposited by the owner into the winning pool through the 'increase_Pool_Rewards' function will be sent.
                if(increasePoolRewards > 0){
                    uint256 additionalRewardsPerPool = increasePoolRewards / numberPools;
                    bool success = myToken.transfer(owner(), additionalRewardsPerPool);
                    require(success);
                }
                emit ValidateWinner(_poolWinner);
            }
        }
        else{
            delete preset_poolWinner;
            emit RenounceWinner(_poolWinner);
        }
    }

    function getPresetWinnerName() public view returns (string memory) {
        require(preset_poolWinner != 0, "Winner not yet declared");
        return poolInfo[preset_poolWinner].name;
    }

    function getWinner() public view returns (uint256) {
        require(poolWinner != 0, "Winner not declared");
        return poolWinner;
    }

    function getWinnerName() public view returns (string memory) {
        require(poolWinner != 0, "Winner not yet declared");
        return poolInfo[poolWinner].name;
    }

    function cancel() onlyOwner checkNotStatus("claim") public {
        betStatus="cancelled";
        emit Cancel();
    }

    function getStatus() public view returns (string memory){
        return  betStatus;
    }

    function getPoolName(uint256 _pool) public view returns (string memory){
        return  poolInfo[_pool].name;
    }

    function getPoolParticipant(uint256 _pool) public view returns (uint256){
        return  poolInfo[_pool].nbParticipants;
    }

    function getPoolTotalBet(uint256 _pool) public view returns (uint256){
        return  poolInfo[_pool].totalamountBet;
    }

    function getPoolsDetail() public view returns (Pool[] memory){
        Pool[] memory listPool = new Pool[](numberPools);

        for (uint256 i = 1; i <= numberPools; i++) {
            listPool[i-1] = poolInfo[i];
        }
        return listPool;
    }

    function getUserTotalBet(address _user) public view returns (uint256){
        uint256 total;
        for(uint256 i = 1; i <= numberPools; i++){
            total += user_pool_bet[_user][i];
        }
        return  total;
    }

    function getUserPoolBet(address _user, uint256 pool) public view returns (uint256){
        return user_pool_bet[_user][pool];
    }

    function getUserWinnerPoolBet(address _user) checkStatus("claim") public view returns (uint256){
        return user_pool_bet[_user][poolWinner];
    }

    function userClaimed(address _user) public view returns (bool){
        return user_claimed[_user];
    }

    function getUserDetailBet(address _user) public view returns (DataUser[] memory){
        DataUser[] memory listData = new DataUser[](numberPools);

        for (uint256 i = 1; i <= numberPools; i++) {
            listData[i-1] = DataUser(poolInfo[i].name, user_pool_bet[_user][i]);
        }
        return listData;
    }

    function getUserReward(address _user) checkStatus("claim") public view returns (uint256){
        if (user_claimed[_user]) {
            return 0;
        }

        uint256 _userAmountBetWinner = user_pool_bet[_user][poolWinner];
        uint256 _poolWinnerTotalBet = poolInfo[poolWinner].totalamountBet;
        uint256 additionalRewardsPerPool = increasePoolRewards / numberPools; // Additional rewards added by the owner to each pool.

        if(_poolWinnerTotalBet == 0){
            return 0;
        }
        else{
            uint256 _rewardUser = ((totalBet - _poolWinnerTotalBet) * _userAmountBetWinner) / (_poolWinnerTotalBet - additionalRewardsPerPool); // The subtraction '_poolWinnerTotalBet - additionalRewardsPerPool' is applied so that the users can fully share all the additional rewards in the losing pools.
            return  _rewardUser;
        } 
    }

    function getreimbursement() nonReentrant checkStatus("cancelled") public {
        require(!user_claimed[msg.sender]);
        uint256 _userAmountBet = getUserTotalBet(msg.sender);
        require(_userAmountBet > 0, "nothing to get");
        bool success = myToken.transfer(msg.sender, _userAmountBet);
        require(success);

        user_claimed[msg.sender] = true;
        db.updateContractsUser(msg.sender);
        emit GetReimbursement(msg.sender, _userAmountBet);
    }

    function withdrawReward() nonReentrant checkStatus("claim") public {
        require(!user_claimed[msg.sender]);
        uint256 _userAmountBetWin = user_pool_bet[msg.sender][poolWinner];
        require(_userAmountBetWin > 0, "nothing to get");
        uint256 _userReward = getUserReward(msg.sender);

        // Send Ecosystem commission
        bool success1 = myToken.transfer(walletEcosystem, _userReward * percentageEcosystem / 100);
        require(success1);
        // Send Charity commission
        bool success2 = myToken.transfer(walletCharity, _userReward * percentageCharity / 100);
        require(success2);
        // Burn
        myToken.burn(_userReward * percentageBurn / 100);
        uint256 reward_received = (_userReward * (100 - percentageEcosystem - percentageCharity - percentageBurn)) / 100;
        // Send Rewards
        bool success3 = myToken.transfer(msg.sender, reward_received);
        require(success3);
        // Send wager
        bool success4 = myToken.transfer(msg.sender , _userAmountBetWin);
        require(success4);

        user_rewards_claimed[msg.sender] = reward_received;
        user_claimed[msg.sender] = true;
        db.modifyUserRewards(msg.sender, _userReward);
        db.modifyUserWins(msg.sender);
        db.updateContractsUser(msg.sender);
        emit Claim(msg.sender, _userReward);
       
    }

}
