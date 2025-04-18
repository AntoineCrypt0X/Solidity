// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

interface IBet{
    function getUserReward(address _user) external view returns (uint256);
    function getStatus() external view returns (string memory);
    function userClaimed(address _user) external view returns (bool);
}