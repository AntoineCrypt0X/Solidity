// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./friendlyPicks.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IBet.sol";


contract ContractFactory is Ownable{

    // Max active contracts / user
    uint256 public max_activeContract;
    // Max old contracts / user
    uint256 public max_oldContract;
    // Minimum Bet
    uint256 public minimumBet;

    struct User {
        address[] activeContracts;
        address[] oldContracts;
    }

    mapping(address => User) private users;

    event ContractDeployed(address indexed user, address contractAddress);

    constructor() Ownable(msg.sender) {
        max_activeContract = 20;
        max_oldContract = 20;
        minimumBet = 1000000000000000000;
    }

    function changeMaxContract(uint256 _max) onlyOwner() external {
        max_activeContract = _max;
    }

    function changeMinimumBet(uint256 _minimum) onlyOwner() external {
        minimumBet = _minimum;
    }

    function removeUserActiveContract(address _user, address _contract) external {
        require(msg.sender == _contract, "Access denied");
        address[] storage contracts = users[_user].activeContracts;
        for (uint256 i = 0; i < contracts.length; i++) {
            if (contracts[i] == _contract) {
                contracts[i] = contracts[contracts.length - 1]; // replace by the last element
                contracts.pop(); // delete the last element
                break;
            }
        }

        address[] storage olds = users[_user].oldContracts;
        if (olds.length >= max_oldContract) {
            for (uint i = 0; i < olds.length - 1; i++) {
                olds[i] = olds[i + 1];
            }
            // delete the last element
            olds.pop();
        }
        // Add the contract
        olds.push(_contract);
    } 

    function getUserActiveContracts(address user) external view returns (address[] memory) {
        return  users[user].activeContracts;
    }

    function getUserOldContracts(address user) external view returns (address[] memory) {
        return  users[user].oldContracts;
    }

    function deployBet(string memory _visibility, uint256 _commissionCreator, uint256 _numberPools, string[] memory _poolName, string[] memory _betDescription, uint256 _endDate, string[] memory _validators, string[] memory _whitelistPlayers) public {
        require(users[msg.sender].activeContracts.length < max_activeContract, "too many active contracts");
        FriendlyPicks newContract = new FriendlyPicks(msg.sender, address(this), _visibility, minimumBet, _commissionCreator, _numberPools, _poolName, _betDescription, _endDate, _validators, _whitelistPlayers);
        users[msg.sender].activeContracts.push(address(newContract));
        emit ContractDeployed(msg.sender, address(newContract));
    }

}