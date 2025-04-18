// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

interface IDatabaseStat {
    function modifyUserBets(address user) external;
    function modifyUserRewards(address user, uint256 rewards) external;
    function modifyUserWins(address user) external;
    function addAuthorizedContract(address contractAddress) external;
    function updateContractsUser(address user) external;
    function AddActiveContract(address user, address _contract) external;
}