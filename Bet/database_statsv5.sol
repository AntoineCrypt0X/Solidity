// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IDatabase_stats.sol";
import "./IBet.sol";

contract Database_Stat is IDatabaseStat, Ownable {

    // Address of the allowed Factory
    address public factory;
    // Mapping user -> ID
    mapping(address => uint256) public user_ID;
    // Mapping ID -> user
    mapping(uint256 => address) public ID_user;
    // Total users
    uint256 public total_users;
    // Mapping Authorized Contracts
    mapping(address => bool) public authorizedContracts;
    // Max active contracts / user
    uint256 max_activeContract;

    struct User {
        uint256 ID;
        uint256 number_bet;
        uint256 total_rewards;
        uint256 total_wins;
        address[] activeContracts;
    }

    mapping(address => User) private users;

    modifier onlyFactory() {
        require(msg.sender == factory, "Not factory");
        _;
    }

    // Modifier Access Contracts 
    modifier onlyAuthorizedContract() {
        require(authorizedContracts[msg.sender], "Access denied: Not an authorized contract");
        _;
    }

    constructor() Ownable(msg.sender) {
        max_activeContract = 50;
    }

    function setFactory(address _factory) external onlyOwner {
        factory = _factory;
    }

    function changeMaxContract(uint256 _max) onlyOwner() external {
        max_activeContract = _max;
    }

    // Function add Authorized Contract
    function addAuthorizedContract(address contractAddress) onlyFactory() external {
        authorizedContracts[contractAddress] = true;
    }

    // Function add 1 to the user's total bets
    function modifyUserBets(address user) external onlyAuthorizedContract {
        if (users[user].number_bet == 0){
            total_users += 1;
            user_ID[user] = total_users;
            ID_user[total_users] = user;
            users[user].ID = total_users;
        }
        users[user].number_bet += 1;
    }

    // Function that adds rewards to the user's total rewards
    function modifyUserRewards(address user, uint256 rewards) external onlyAuthorizedContract {
        users[user].total_rewards += rewards;
    }

    // Function that increments the user's total wins by 1.
    function modifyUserWins(address user) external onlyAuthorizedContract {
        users[user].total_wins += 1;
    }

    function isAuthorizedContract(address _contract) public view returns (bool) {
        return authorizedContracts[_contract];
    }

    function getTotalUsers() external view returns (uint256) {
        return  total_users;
    }

    function getIdUser(uint256 _id) external view returns (address) {
        return  ID_user[_id];
    }

    function getUserId(address user) external view returns (uint256) {
        return  users[user].ID;
    }

    function getUserTotalBets(address user) external view returns (uint256) {
        return  users[user].number_bet;
    }

    function getUserTotalRewards(address user) external view returns (uint256) {
        return  users[user].total_rewards;
    }

    function getUserTotalWins(address user) external view returns (uint256) {
        return  users[user].total_wins;
    }

    function getUserActiveContracts(address user) external view returns (address[] memory) {
        return  users[user].activeContracts;
    }

    function getContractToClaim(address user) external view returns (address[] memory) {
        address[] memory userContract = users[user].activeContracts;
        address[] memory to_claim = new address[](userContract.length);
        uint256 count = 0;
        
        for(uint256 i=0; i < userContract.length; i++){
            IBet bet = IBet(userContract[i]);
            if(keccak256(abi.encodePacked(bet.getStatus())) == keccak256(abi.encodePacked("claim"))){
                uint256 _userRewards = bet.getUserReward(user);
                if(_userRewards > 0){
                    to_claim[count] = userContract[i];
                    count++;
                }
            }
            if(keccak256(abi.encodePacked(bet.getStatus())) == keccak256(abi.encodePacked("cancelled"))){
                to_claim[count] = userContract[i];
                count++;
            }
        }
        address[] memory final_list = new address[](count);
        for (uint256 j = 0; j < count; j++) {
            final_list[j] = to_claim[j];
        }
        return final_list;
    }

    function getContractOpen(address user) external view returns (address[] memory) {
        address[] memory userContract = users[user].activeContracts;
        address[] memory is_active = new address[](userContract.length);
        uint256 count = 0;
        
        for(uint256 i=0; i < userContract.length; i++){
            IBet bet = IBet(userContract[i]);
            if(keccak256(abi.encodePacked(bet.getStatus())) == keccak256(abi.encodePacked("open"))){
                is_active[count] = userContract[i];
                count++;
            }
        }
        address[] memory final_list = new address[](count);
        for (uint256 j = 0; j < count; j++) {
            final_list[j] = is_active[j];
        }
        return final_list;
    }

    function updateContractsUser(address user) external onlyAuthorizedContract {
        address[] memory userContract = users[user].activeContracts;
        for(uint256 i = 0; i < userContract.length; i++){
            IBet bet = IBet(userContract[i]);
            bool claimed = bet.userClaimed(user);

            if(keccak256(abi.encodePacked(bet.getStatus())) == keccak256(abi.encodePacked("cancelled")) && claimed){
                _removeUserActiveContract(user, userContract[i]);
            }

            if(keccak256(abi.encodePacked(bet.getStatus())) == keccak256(abi.encodePacked("claim"))){
                uint256 _userRewards = bet.getUserReward(user);
                if(_userRewards == 0){
                    _removeUserActiveContract(user, userContract[i]);
                }
            }

        }
    }

    function _removeUserActiveContract(address _user, address _contract) internal {
        address[] storage contracts = users[_user].activeContracts;
        for (uint256 i = 0; i < contracts.length; i++) {
            if (contracts[i] == _contract) {
                contracts[i] = contracts[contracts.length - 1]; // replace by the last element
                contracts.pop(); // delete the last element
                return;
            }
        }
    } 

    function AddActiveContract(address user, address _contract) external onlyAuthorizedContract {
        require(users[user].activeContracts.length < max_activeContract, "too many active contracts");
        users[user].activeContracts.push(_contract);
    }
}
