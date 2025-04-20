// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./token.sol";
import "./IRouter.sol";
import "./friendlyPicks_Factory2.sol";

interface IRegistration{
    function balanceOf(address owner) external view returns (uint256 balance);
    function getAlias(address owner) external view returns (string memory _alias);
    function getAddressAlias(string memory _alias) external view returns (address _aliasAddress);
}

contract FriendlyPicks is ReentrancyGuard {
    // ============= VARIABLES ============

    IRegistration public immutable NFTcontract = IRegistration("NFT contract address");

    // Database statistics interface
    ContractFactory public immutable factory;
    // Smart Contract address of the betting token
    Token20 public immutable myToken = Token20("Token contract address");
    
    // Minimum bet
    uint256 public minimumBet;
    // Commission reward burnt
    uint256 public commissionBurn = 1;
    //commission creator, only for public picks
    uint256 public commissionCreator;
    // Admin wallet
    string[] public validators;
    // whitelisted participants, only for private picks
    mapping(string => bool) public whitelistPlayers;
    // Bet visibility: public or private
    string public visibility;
    // Bet title
    string public title;
    // Bet rules
    string public rules;
    // Timestamp of when the bet period starts
    uint256 public startDate;
    // Timestamp of when the bet period ends
    uint256 public endDate;
    // Number of pools (i.e., outcomes of the bet)
    uint256 public numberPool;
    // Owner address
    address public owner;
    // Owner alias
    string public ownerAlias;

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
    // Total tokens betTotal tokens bet
    uint256 public totalBet;
    // Total number of participants
    uint256 public totalParticipants;
    // Bet status
    string public betStatus;
    // Pool pre-set winner
    uint256 public preset_poolWinner;
    // Pool winner
    uint256 public poolWinner;

    event Bet(address indexed  user, uint256 _poolSelected, uint256 amount);
    event Claim(address indexed  user, uint256 amount);
    event Cancel();
    event GetReimbursement(address indexed  user, uint256 amount);
    event PresetWinner(uint256 winner);
    event ValidateWinner(uint256 winner);
    event RenounceWinner(uint256 winner);

    constructor(address _owner, address _factory, string memory _visibility, uint256 _minimumBet, uint256 _commissionCreator, uint256 _numberPools, string[] memory _poolName, string[] memory _betDescription, uint256 _endDate, string[] memory _validators, string[] memory _whitelistPlayers) {
        require(NFTcontract.balanceOf(_owner) > 0);
        require(keccak256(abi.encodePacked(_visibility)) == keccak256(abi.encodePacked("public")) || keccak256(abi.encodePacked(_visibility)) == keccak256(abi.encodePacked("private")), "Input must be 'public' or 'private'");
        require(_minimumBet > 0);
        require(_numberPools >= 2 && _numberPools <= 5, "Invalid number of pools");
        require(_poolName.length == _numberPools, "Size of the pool name list must be equal to the number of pools");
        require(_commissionCreator >= 0 && _commissionCreator <= 8, "Invalid commission");
        require(_betDescription.length == 2, "Invalid description input");
        require(_validators.length > 0, "Empty validator list");

        owner = _owner;
        factory = ContractFactory(_factory);
        visibility = _visibility;
        minimumBet = _minimumBet;
        if(keccak256(abi.encodePacked(_visibility)) == keccak256(abi.encodePacked("private"))){
            commissionCreator = 0;
        }
        else{
            commissionCreator = _commissionCreator;
        }
        numberPool = _numberPools;

        // check: no double in pool names
        for (uint k = 0; k < _poolName.length; k++) {
            for (uint y = k + 1; y < _poolName.length; y++) {
                require(keccak256(abi.encodePacked(_poolName[k])) != keccak256(abi.encodePacked(_poolName[y])), "double in poolnames");
            }
        }

        // check: no special characters
        bytes memory nameBytes;
        for(uint256 j = 0; j < _poolName.length; j++){
            nameBytes = bytes(_poolName[j]);
            for (uint256 i = 0; i < nameBytes.length; i++) {
                require(nameBytes[i] != ',' && nameBytes[i] != '"' && nameBytes[i] != '[' && nameBytes[i] != ']' && nameBytes[i] != '\\', "special characters");
            }
            poolInfo[j+1].name = _poolName[j];
        }
        
        title = _betDescription[0];
        rules = _betDescription[1];
        startDate = block.timestamp;
        require(_endDate > startDate, " Invalid end date");
        endDate = _endDate;
        betStatus = "open";

        string memory _ownerAlias = NFTcontract.getAlias(_owner);
        whitelistPlayers[_ownerAlias] = true;
        ownerAlias = _ownerAlias;
        
        address _user;
        for (uint256 i = 0; i < _validators.length; i++) {
            _user = NFTcontract.getAddressAlias(_validators[i]);
            require(_user != owner, "Owner cannot be a validator");
            require(NFTcontract.balanceOf(_user) > 0);
        }

        validators = _validators;

        for(uint256 k = 0; k < _whitelistPlayers.length; k++){
            _user = NFTcontract.getAddressAlias(_whitelistPlayers[k]);
            if(NFTcontract.balanceOf(_user) > 0){
                whitelistPlayers[_whitelistPlayers[k]] = true;
            }
        }
        
    }

    // ============= MODIFIERS ============

    modifier isOwner {
      require ( msg.sender == owner) ;
      _ ;
    }

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

    function bet(uint256 _poolSelected, uint256 numberTokens) nonReentrant checkNotStatus("cancelled") checkBeforeEndDate public {
        if(keccak256(abi.encodePacked(visibility)) == keccak256(abi.encodePacked("private"))){
            require(NFTcontract.balanceOf(msg.sender) > 0);
            string memory _userAlias = NFTcontract.getAlias(msg.sender);
            require(whitelistPlayers[_userAlias], "Not whitelisted");
        }
        require(_poolSelected >= 1 && _poolSelected <= numberPool, "invalid pool selected");
        require(numberTokens >= minimumBet, "invalid token sent");

        if(user_pool_bet[msg.sender][_poolSelected] == 0){
            poolInfo[_poolSelected].nbParticipants += 1;
        }

        uint256 currentBetUser = getUserTotalBet(msg.sender);

        if(currentBetUser == 0){
            totalParticipants += 1;
        }

        bool success = myToken.transferFrom(msg.sender, address(this), numberTokens);
        require(success);
        user_pool_bet[msg.sender][_poolSelected] += numberTokens;
        poolInfo[_poolSelected].totalamountBet += numberTokens;
        totalBet += numberTokens;
        emit Bet(msg.sender, _poolSelected, numberTokens);
    }

    function isOver() external view returns (bool) {
        return (block.timestamp > endDate);
    }

    function isWhitelisted(string memory _alias) external view returns (bool) {
        return whitelistPlayers[_alias];
    }

    function isWhitelistedAddress(address _user) external view returns (bool) {
        string memory _alias = NFTcontract.getAlias(_user);
        return whitelistPlayers[_alias];
    }

    function addtoWhitelist(string[] memory _whitelistPlayers) external  {
        require(msg.sender == owner || isValidator(msg.sender));
        require(keccak256(abi.encodePacked(visibility)) == keccak256(abi.encodePacked("private")));
        address _user;
        for(uint256 k = 0; k < _whitelistPlayers.length; k++){
            _user = NFTcontract.getAddressAlias(_whitelistPlayers[k]);
            if(NFTcontract.balanceOf(_user) > 0){
                whitelistPlayers[_whitelistPlayers[k]] = true;
            }
        }
    }

    function addValidator(string memory _alias) isOwner external  {
        address _user = NFTcontract.getAddressAlias(_alias);
        require(_user != owner);
        require(preset_poolWinner == 0);
        validators.push(_alias);
    }

    function removeValidator(uint256 index) isOwner external {
        require(index < validators.length);
        require(validators.length >= 2);
        require(preset_poolWinner == 0);

        // Move the last element into the place to delete
        validators[index] = validators[validators.length - 1];
        // Remove the last element
        validators.pop();

    }

    function isValidator(address _address) public view returns (bool) {
        string memory _alias = NFTcontract.getAlias(_address);
        for (uint256 i = 0; i < validators.length; i++) {
            if (keccak256(abi.encodePacked(validators[i] ))== keccak256(abi.encodePacked(_alias))) {
                return true;
            }
        }
        return false;
    }

    // Result pre-set by the Owner
    function preset_winner(uint256 _poolWinner) checkNotStatus("claim") checkNotStatus("cancelled") isOwner checkAfterEndDate public {
        require(_poolWinner >= 1 && _poolWinner <= numberPool, "invalid pool");
        preset_poolWinner = _poolWinner;
        emit PresetWinner(_poolWinner);
    }

    function getValidators() external view returns (string[] memory) {
        return  validators;
    }
    
    // Only by a validator
    function set_winner(uint256 _poolWinner) checkNotStatus("claim") checkNotStatus("cancelled") checkAfterEndDate public {
        require(preset_poolWinner != 0, "Winner not preset yet");
        require(msg.sender != owner, "Owner can't be a validator");
        require(isValidator(msg.sender), "You are not authorized to call this function");
        require(_poolWinner >= 1 && _poolWinner <= numberPool, "invalid pool");
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
                emit ValidateWinner(_poolWinner);
            }
            factory.removeUserActiveContract(owner, address(this));
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
        require(poolWinner != 0, "Winner not yet declared");
        return poolWinner;
    }

    function getWinnerName() public view returns (string memory) {
        require(poolWinner != 0, "Winner not yet declared");
        return poolInfo[poolWinner].name;
    }

    function cancel() isOwner checkNotStatus("claim") public {
        betStatus="cancelled";
        factory.removeUserActiveContract(owner, address(this));
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

    function getUserPoolBet(address _user, uint256 pool) public view returns (uint256){
        return user_pool_bet[_user][pool];
    }

    function getUserWinnerPoolBet(address _user) checkStatus("claim") public view returns (uint256){
        require(poolWinner != 0, "Winner not yet declared");
        return user_pool_bet[_user][poolWinner];
    }

    function getUserTotalBet(address _user) public view returns (uint256){
        uint256 total;

        for(uint256 i = 1; i <= numberPool; i++){
            total += user_pool_bet[_user][i];
        }

        return  total;
    }

    function getUserDetailBet(address _user) public view returns (DataUser[] memory){
        DataUser[] memory listData = new DataUser[](numberPool);

        for (uint256 i = 1; i <= numberPool; i++) {
            listData[i-1] = DataUser(poolInfo[i].name, user_pool_bet[_user][i]);
        }
        return listData;
    }

    function userClaimed(address _user) public view returns (bool){
        return user_claimed[_user];
    }

    function getPoolsDetail() public view returns (Pool[] memory){
        Pool[] memory listPool = new Pool[](numberPool);

        for (uint256 i = 1; i <= numberPool; i++) {
            listPool[i-1] = poolInfo[i];
        }
        return listPool;
    }

    function getUserReward(address _user) checkStatus("claim") public view returns (uint256){
        if (user_claimed[_user]) {
            return 0;
        }

        uint256 _userAmountBetWinner = user_pool_bet[_user][poolWinner];
        uint256 _poolWinnerTotalBet = poolInfo[poolWinner].totalamountBet;

        if(_poolWinnerTotalBet == 0){
            return 0;
        }
        else{
            uint256 _rewardUser = ((totalBet - _poolWinnerTotalBet) * _userAmountBetWinner) / _poolWinnerTotalBet; 
            return  _rewardUser;
        } 
    }

    function getreimbursement() nonReentrant checkStatus("cancelled") public {
        require(!user_claimed[msg.sender]);
        uint256 _userAmountBet;

        for(uint256 i = 1; i <= numberPool; i++){
            _userAmountBet += user_pool_bet[msg.sender][i];
        }

        bool success = myToken.transfer(msg.sender, _userAmountBet);
        require(success);

        for(uint256 i = 1; i <= numberPool; i++){
            delete user_pool_bet[msg.sender][i];
        }

        user_claimed[msg.sender] = true;
        emit GetReimbursement(msg.sender, _userAmountBet);
    }

    function getRewardWithdraw() nonReentrant checkNotStatus("cancelled") checkAfterEndDate public {
        require(!user_claimed[msg.sender]);
        uint256 _userReward = getUserReward(msg.sender);
        uint256 _userAmountBetWin = user_pool_bet[msg.sender][poolWinner];
        require(_userAmountBetWin > 0, "nothing to get");

        bool success1 = myToken.transfer(owner, _userReward * commissionCreator / 100);
        require(success1);
        myToken.burn(_userReward * commissionBurn / 100);
        uint256 send_to_user = 100 - commissionCreator - commissionBurn;
        bool success2 = myToken.transfer(msg.sender, _userReward * send_to_user / 100);
        require(success2);
        bool success3 = myToken.transfer(msg.sender, _userAmountBetWin);
        require(success3);

        user_rewards_claimed[msg.sender] = _userReward * send_to_user / 100;
        user_claimed[msg.sender] = true;
        emit Claim(msg.sender, _userReward);
    }

}
