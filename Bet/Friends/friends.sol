// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IRegistration{
    function balanceOf(address owner) external view returns (uint256 balance);
    function getAlias(address owner) external view returns (string memory _alias);
    function getAddressAlias(string memory _alias) external view returns (address _aliasAddress);
}

contract FriendList is Ownable{

    IRegistration public NFTcontract;

    uint256 public max_friend;

    struct User {
        address[] friends;
        string[] friends_alias;
    }

    mapping(address => User) private users;

    event FriendAdded(address indexed user, address[] indexed friends);
    event FriendRemoved(address indexed user, address[] indexed friends);

    constructor(address NFTAddress) Ownable(msg.sender) {
        NFTcontract = IRegistration(NFTAddress);
        max_friend = 100;
    }

    function addFriends(address[] memory list_friends) external returns (address[] memory) {
        address[] memory added_list = new address[](list_friends.length);
        uint256 count = 0;
        string memory _alias;
        require(NFTcontract.balanceOf(msg.sender) > 0,"You need to register first");
        require(users[msg.sender].friends.length < max_friend, "Maximum number of friends reached");
        
        for (uint256 i = 0; i < list_friends.length; i++) {
            address _friend = list_friends[i];
            if(_friend != msg.sender && _friend != address(0)){
                if(!isFriend(msg.sender,_friend) && NFTcontract.balanceOf(_friend) > 0){
                    if(users[msg.sender].friends.length < max_friend){
                        users[msg.sender].friends.push(_friend);
                        _alias = NFTcontract.getAlias(_friend);
                        users[msg.sender].friends_alias.push(_alias);
                        added_list[count] = _friend;
                        count++;
                    }
                }
            }
        }
        address[] memory finalAddedFriends = new address[](count);

        for (uint256 j = 0; j < count; j++) {
            finalAddedFriends[j] = added_list[j];
        }

        emit FriendAdded(msg.sender, finalAddedFriends);
        return finalAddedFriends;
    }

    function addFriendsAlias(string[] memory list_Aliasfriends) external returns (address[] memory) {
        // transform the alias list into an address list
        address[] memory list_friends = new address[](list_Aliasfriends.length);

        for (uint256 j = 0; j < list_Aliasfriends.length; j++) {
            list_friends[j]=NFTcontract.getAddressAlias(list_Aliasfriends[j]);
        }

        address[] memory added_list = new address[](list_friends.length);
        uint256 count = 0;
        string memory _alias;
        require(NFTcontract.balanceOf(msg.sender) > 0,"You need to register first");

        for (uint256 i = 0; i < list_friends.length; i++) {
            address _friend = list_friends[i];
            if(_friend != msg.sender && _friend != address(0)){
                if(!isFriend(msg.sender,_friend) && NFTcontract.balanceOf(_friend) > 0){
                    if(users[msg.sender].friends.length < max_friend){
                        users[msg.sender].friends.push(_friend);
                        _alias = list_Aliasfriends[i];
                        users[msg.sender].friends_alias.push(_alias);
                        added_list[count] = _friend;
                        count++;
                    }
                }
            }
        }
        address[] memory finalAddedFriends = new address[](count);

        for (uint256 j = 0; j < count; j++) {
            finalAddedFriends[j] = added_list[j];
        }

        emit FriendAdded(msg.sender, finalAddedFriends);
        return finalAddedFriends;
    }

    function removeFriends(address[] memory list_friends) external {
        address[] memory removedFriends = new address[](list_friends.length);
        uint256 removedCount = 0;

        for (uint256 i = 0; i < list_friends.length; i++) {
            address _friend = list_friends[i];
            if (!isFriend(msg.sender, _friend)) {
                continue;
            }
            _removeFriend(msg.sender, _friend);
            removedFriends[removedCount] = _friend;
            removedCount++;
        }

        address[] memory actualRemovedFriends = new address[](removedCount);

        for (uint256 j = 0; j < removedCount; j++) {
            actualRemovedFriends[j] = removedFriends[j];
        }

        emit FriendRemoved(msg.sender, actualRemovedFriends);
    }

    function removeFriendsAlias(string[] memory list_Aliasfriends) external {
        // transform the alias list into an address list
        address[] memory list_friends = new address[](list_Aliasfriends.length);

        for (uint256 j = 0; j < list_Aliasfriends.length; j++) {
            list_friends[j] = NFTcontract.getAddressAlias(list_Aliasfriends[j]);
        }

        address[] memory removedFriends = new address[](list_friends.length);
        uint256 removedCount = 0;

        for (uint256 i = 0; i < list_friends.length; i++) {
            address _friend = list_friends[i];
            if (!isFriend(msg.sender, _friend)) {
                continue;
            }
            _removeFriend(msg.sender, _friend);
            removedFriends[removedCount] = _friend;
            removedCount++;
        }
        address[] memory actualRemovedFriends = new address[](removedCount);

        for (uint256 j = 0; j < removedCount; j++) {
            actualRemovedFriends[j] = removedFriends[j];
        }

        emit FriendRemoved(msg.sender, actualRemovedFriends);
    }

    function _removeFriend(address _user, address _friend) internal {
        address[] storage friends = users[_user].friends;
        string[] storage friendsAlias = users[_user].friends_alias;

        for (uint256 i = 0; i < friends.length; i++) {
            if (friends[i] == _friend) {
                friends[i] = friends[friends.length - 1]; // replace with the last element
                friends.pop(); // delete the last element
                friendsAlias[i] = friendsAlias[friendsAlias.length - 1]; // replace with the last element
                friendsAlias.pop(); // delete the last element
                return;
            }
        }
    }

    function change_maxFriends(uint256 _max) onlyOwner external {
        max_friend=_max;
    }

    function getFriends(address _user) external view returns (address[] memory) {
        return users[_user].friends;
    }

    function getNumberFriends(address _user) external view returns (uint256) {
        return users[_user].friends.length;
    }

    function getFriendsAlias(address _user) external view returns (string[] memory) {
        return users[_user].friends_alias;
    }

    function isFriend(address _user, address _friend) public view returns (bool) {
        address[] memory friends = users[_user].friends;

        for (uint256 i = 0; i < friends.length; i++) {
            if (friends[i] == _friend) {
                return true;
            }
        }
        return false;
    }

    function isFriendAlias(string memory _user, string memory _friend) public view returns (bool) {
        address _userAdress = NFTcontract.getAddressAlias(_user);
        address _friendAdress = NFTcontract.getAddressAlias(_friend);
        address[] memory friends = users[_userAdress].friends;

        for (uint256 i = 0; i < friends.length; i++) {
            if (friends[i] == _friendAdress) {
                return true;
            }
        }
        return false;
    }

}