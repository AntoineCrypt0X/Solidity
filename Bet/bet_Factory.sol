// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./bet_paramv8_2.sol";
import "./IDatabase_stats.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ContractFactory is Ownable {

    IDatabaseStat public db;
    mapping(address => bool) public whitelist;
    address public approveDelegator;

    event ContractBetDeployed(address indexed user, address contractAddress);
    event Whitelisted(address indexed user, bool status);

    modifier onlyWhitelisted() {
        require(whitelist[msg.sender], "You are not whitelisted");
        _;
    }

    constructor(address dbAddress, address _approveDelegator) Ownable(msg.sender) {
        db = IDatabaseStat(dbAddress);
        approveDelegator = _approveDelegator;
        whitelist[msg.sender] = true;
    }

    function addToWhitelist(address user) external onlyOwner {
        whitelist[user] = true;
        emit Whitelisted(user, true);
    }

    function removeFromWhitelist(address user) external onlyOwner {
        whitelist[user] = false;
        emit Whitelisted(user, false);
    }

    function deployBet(uint256 _minimumBet, uint256[] memory _commissions, address[] memory _wallets, uint256 _numberPools, string[] memory _poolName, string[] memory _betDescription, uint256 _endDate, address[] memory _validators) public onlyWhitelisted {
        bettest newContract = new bettest(msg.sender, address(db), approveDelegator, _minimumBet, _commissions, _wallets, _numberPools, _poolName, _betDescription, _endDate, _validators);
        db.addAuthorizedContract(address(newContract));
        emit ContractBetDeployed(msg.sender, address(newContract));
    }
}