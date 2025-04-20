// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

interface IDatabaseFriendlyPicks {
    function updateContractsUser(address user) external;
    function AddCreateActiveContract(address user, address _contract) external;
}