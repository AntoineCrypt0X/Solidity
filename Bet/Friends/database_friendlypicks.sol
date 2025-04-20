// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;
import "@openzeppelin/contracts/access/Ownable.sol";

interface IBet{
    function getUserReward(address _user) external view returns (uint256);
    function getStatus() external view returns (string memory);
}

contract Database_FriendlyPicks is Ownable {

    uint256 max_createActiveContract;

    // mapping user active contracts
    mapping(address => address[]) public user_createActiveContracts;

    struct User {
        address[] activeContracts;
    }

    mapping(address => User) private users;

    constructor() Ownable(msg.sender) {
        max_createActiveContract = 10;
    }

    function changeMaxContract(uint256 _max) onlyOwner() external {
        max_createActiveContract = _max;
    }

    function getUserActiveContracts(address user) external view returns (address[] memory) {
        return  users[user].activeContracts;
    }

    function deleteActiveContractUser(address _user, address _contract) external {
        IBet bet = IBet(_contract);
        if(keccak256(abi.encodePacked(bet.getStatus())) != keccak256(abi.encodePacked("open"))){
            _removeUserActiveContract(_user, _contract);
        }
    }

    function _removeUserActiveContract(address _user, address _contract) internal {
        address[] storage contracts = users[_user].activeContracts;
        for (uint256 i = 0; i < contracts.length; i++) {
            if (contracts[i] == _contract) {
                contracts[i] = contracts[contracts.length - 1];
                contracts.pop();
                return;
            }
        }
    } 

    function AddActiveContract(address user, address _contract) external {
        require(users[user].activeContracts.length < max_createActiveContract, "too many active contracts");
        users[user].activeContracts.push(_contract);
    }
}
