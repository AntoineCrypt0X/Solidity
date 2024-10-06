// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// Whitelist a list of addresses that will claim over 1000 days a personal amount
contract Claim is Ownable, ReentrancyGuard {

    // Contract address of the token
    IERC20 public immutable claimToken;

    mapping(address => bool) public userIsWhitelisted;

    mapping(address => uint) public userLastClaim;

    mapping(address => uint) public userStartClaimPeriod;

    mapping(address => uint) public userEndClaimPeriod;

    mapping(address => uint) public userTokensToClaim;

    mapping(address => uint) public userTokensLeftToClaim;

    event Add_Users_Claim(uint256[] listTokensToClaim,address[] listAddress);
    event Change_Users_Claim(uint256[]listTokensToClaim,address[] listAddress);
    event Remove_Users_Claim(address[] listAddress);

    constructor(address _claimToken) Ownable(msg.sender){
        claimToken = IERC20(_claimToken);
    }

    //This function returns the unixtime of the next day 12:00 am. Used when users are whitelisted.Their start claiming period will start there.
    function next_midnight() public view returns (uint256) {
        uint256 now_time=block.timestamp;
        uint256 days_since_1970=now_time/86400;
        uint256 last_midnight= days_since_1970*86400;
        uint256 rest=now_time-last_midnight;
        return now_time + (86400-rest);
    }

    // Function that whitelist users. The claiming period lasts 1000 days.
    function add_Users_Claiming_List(uint256[] calldata listTokensToClaim, address[] calldata listAddress) onlyOwner public returns (bool) {
        require(listTokensToClaim.length==listAddress.length);
        uint256 users_start_claim_period=next_midnight();
        for(uint i=0;i<listAddress.length;i++){
            address address_user=listAddress[i];
            uint256 tokens_user=listTokensToClaim[i];
            // only users who are not whitelisted yet can be added
            if(!userIsWhitelisted[address_user]){
                userIsWhitelisted[address_user]=true;
                userStartClaimPeriod[address_user]=users_start_claim_period;
                userEndClaimPeriod[address_user]=userStartClaimPeriod[address_user] + 1000 days;
                userLastClaim[address_user]=userStartClaimPeriod[address_user];
                userTokensLeftToClaim[address_user]=tokens_user*1e18;
                userTokensToClaim[address_user]=userTokensLeftToClaim[address_user];
            }
        }
        emit Add_Users_Claim(listTokensToClaim,listAddress);
        return true;
    }

    // To correct the number of tokens assigned to a Wallet
    function change_Users_TokensToClaim(uint256[] calldata listTokensToClaim, address[] calldata listAddress) onlyOwner public returns (bool) {
        require(listTokensToClaim.length==listAddress.length);
        uint256 users_start_claim_period=next_midnight();
        for(uint i=0;i<listAddress.length;i++){
            address address_user=listAddress[i];
            uint256 new_tokens_user=listTokensToClaim[i]*1e18;
            if(userIsWhitelisted[address_user]){
                // The claim period restart for the user
                userStartClaimPeriod[address_user]=users_start_claim_period;
                userEndClaimPeriod[address_user]=userStartClaimPeriod[address_user] + 1000 days;
                userLastClaim[address_user]=userStartClaimPeriod[address_user];
                userTokensToClaim[address_user]=new_tokens_user;
                userTokensLeftToClaim[address_user]=userTokensToClaim[address_user];

                if(new_tokens_user==0){
                    delete userIsWhitelisted[address_user];
                    delete userStartClaimPeriod[address_user];
                    delete userEndClaimPeriod[address_user];
                    delete userLastClaim[address_user];
                    delete userTokensToClaim[address_user];
                    delete userTokensLeftToClaim[address_user];
                }
            }
        }
        emit Change_Users_Claim(listTokensToClaim,listAddress);
        return true;
    }

    // To remove a Wallet from the whitelist
    function remove_from_List(address[] calldata listAddress) onlyOwner public returns (bool) {
        for(uint i=0;i<listAddress.length;i++){
            address address_user=listAddress[i];
            delete userIsWhitelisted[address_user];
            delete userStartClaimPeriod[address_user];
            delete userEndClaimPeriod[address_user];
            delete userLastClaim[address_user];
            delete userTokensToClaim[address_user];
            delete userTokensLeftToClaim[address_user];
        }
        emit Remove_Users_Claim(listAddress);
        return true;
    }

    // Return the number of tokens that a user can claim now
    function TokenAvailableToClaim(address _user) public view returns (uint256){
        if(block.timestamp>userStartClaimPeriod[_user]){
            if (!userIsWhitelisted[_user]){
                return 0;
            }
            else {
                uint256 user_tokens_perDay=userTokensToClaim[_user]/1000;
                uint256 now_time=block.timestamp;
                if (now_time>userEndClaimPeriod[_user]) {
                    now_time=userEndClaimPeriod[_user];
                }
                //To compute the days past since the last update. 86400 seconds per day
                uint256 user_days_lastUpdate=(now_time-userLastClaim[_user])/86400;
                if (user_days_lastUpdate==0){
                    return 0;
                }
                else{
                    uint256 tokens_available=user_days_lastUpdate*user_tokens_perDay;
                    return tokens_available;
                }
            }
        }
        else{
            return 0;
        }
    }

    // claim function
    function claim() public nonReentrant returns (bool) {
        require(userIsWhitelisted[msg.sender],"Not Whitelisted");
        require(block.timestamp>userStartClaimPeriod[msg.sender]);
        uint256 user_tokens_perDay=userTokensToClaim[msg.sender]/1000;
        uint256 now_time=block.timestamp;
        if (now_time>userEndClaimPeriod[msg.sender]) {
            now_time=userEndClaimPeriod[msg.sender];
        }
        //To compute the days past since the last update. 86400 seconds per day
        uint256 user_days_lastUpdate=(now_time-userLastClaim[msg.sender])/86400;
        require(user_days_lastUpdate>0,"Nothing to claim");
        uint256 tokens_available=user_days_lastUpdate*user_tokens_perDay;
        claimToken.transfer(msg.sender, tokens_available);
        userLastClaim[msg.sender]=userLastClaim[msg.sender]+(user_days_lastUpdate*86400);
        userTokensLeftToClaim[msg.sender]-=tokens_available;
        return true;
    }

    function return_To_Owner(uint256 _amount) external onlyOwner {
        claimToken.transfer(msg.sender, _amount);
    }

}
