// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./token.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// Betting contract. Users bet on 1 or more proposed teams. Users who bet on the winning team share the “losing pool” in proportion to their share of the winning pool.
contract bettest is Ownable, ReentrancyGuard {
    // ============= VARIABLES ============

    // Contract address of the token
    Token20 public myToken;
    
    //Minimum bet
    uint256 public minimumBet;

    //commission reward burnt
    uint256 public percentageBurn;
    //commission charity
    uint256 public percentageCharity;
    //commission reward to team
    uint256 public percentageTeam;
    //team wallet
    address public walletTeam;
    //charity wallet
    address public walletCharity;
    //Bet description
    string public description;
    //Bet domain
    string public domain;
    // Timestamp of when the bet period starts
    uint256 public StartDate;
    // Timestamp of when the bet period ends
    uint256 public EndDate;
    // Number of teams
    uint256 public numberTeams;

    struct Team {
        string name;
        uint256 totalamountBet;
        uint256 nbParticipants;
    }

    // The address of the player and => the user info
    mapping(uint256 => Team) public teamInfo;

    mapping(address=> mapping(uint256 => uint256)) public user_team_bet;

    // total bet
    uint256 public totalBet;

    // bet status
    string public betStatus;

    //team winner
    uint256 public teamWinner;

    event Bet(address indexed  user, uint256 _teamSelected, uint256 amount);
    event Claim(address indexed  user, uint256 amount);
    event GetReimbursement(address indexed  user, uint256 amount);
    event SetWinner(uint256 winner);

    constructor(address token,  uint256 _minimumBet, address _walletTeam, address _walletCharity, uint256 _numberTeams, string[] memory teamName, string[] memory betDescription, uint256 _EndDate) Ownable(msg.sender) {
        myToken = Token20(token);
        require(_numberTeams>=2);
        require(teamName.length==_numberTeams);
        require(betDescription.length==2);
        minimumBet = _minimumBet;
        walletTeam=_walletTeam;
        walletCharity=_walletCharity;
        numberTeams=_numberTeams;
        for(uint i=1;i<=teamName.length;i++){
            teamInfo[i].name=teamName[i];
        }
        description=betDescription[0];
        domain=betDescription[1];
        StartDate=block.timestamp;
        betStatus="open";
        EndDate=_EndDate;

        //Commissions
        percentageBurn=1;
        percentageCharity=1;
        percentageTeam=8;
    }

    // ============= MODIFIERS ============

    modifier checkAfterStartDate {
      require ( block.timestamp > StartDate) ;
      _ ;
    }

    modifier checkBeforeEndDate {
      require ( block.timestamp < EndDate) ;
      _ ;
    }

    modifier checkAfterEndDate {
      require ( block.timestamp > EndDate) ;
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

    function set_initial_bet(uint256 _nbtokens) onlyOwner public  {
        for(uint256 i=1;i<=numberTeams;i++){
            teamInfo[i].totalamountBet=_nbtokens;
            totalBet+=_nbtokens;
        }
        myToken.transferFrom(msg.sender, address(this), totalBet);
    }

    function bet(uint256 _teamSelected, uint256 numberTokens) nonReentrant checkNotStatus("cancelled") checkAfterStartDate checkBeforeEndDate public {
        require(_teamSelected>=1 && _teamSelected<=numberTeams,"invalid team selected");
        require(numberTokens >= minimumBet,"invalid token sent");
        if(user_team_bet[msg.sender][_teamSelected]==0){
            teamInfo[_teamSelected].nbParticipants+=1;
        }
        myToken.transferFrom(msg.sender, address(this), numberTokens);
        user_team_bet[msg.sender][_teamSelected]+=numberTokens;
        teamInfo[_teamSelected].totalamountBet+=numberTokens;
        totalBet+=numberTokens;
        emit Bet(msg.sender, _teamSelected, numberTokens);
    }

    function set_winner(uint256 _teamWinner) onlyOwner checkAfterEndDate public {
        require(_teamWinner>=1 && _teamWinner<=numberTeams,"invalid team");
        teamWinner=_teamWinner;
        betStatus="claim";
        emit SetWinner(_Winner);
    }

    function cancel() onlyOwner checkNotStatus("claim") public {
        betStatus="cancelled";
    }

    function getUserReward(address _user) checkStatus("claim") checkAfterEndDate public view returns (uint256){
        uint256 _userAmountBetWinner = user_team_bet[_user][teamWinner];
        uint256 _teamWinnerTotalBet = teamInfo[teamWinner].totalamountBet;
        uint256 _rewardUser = ((totalBet-_teamWinnerTotalBet)*_userAmountBetWinner)/_teamWinnerTotalBet;

        return  _rewardUser;
    }

    function getreimbursement() nonReentrant checkStatus("cancelled") public {
        uint256 _userAmountBet;
        for(uint256 i=1;i<=numberTeams;i++){
            _userAmountBet += user_team_bet[msg.sender][i];
        }
        require(_userAmountBet>0,"nothing to get");
        myToken.transfer(msg.sender,_userAmountBet);
        for(uint256 i=1;i<=numberTeams;i++){
            delete user_team_bet[msg.sender][i];
        }

        emit GetReimbursement(msg.sender, _userAmountBet);
    }

    function getRewardWithdraw() nonReentrant checkNotStatus("cancelled") checkAfterEndDate public {
        uint256 _userReward=getUserReward(msg.sender);
        require(_userReward>0,"nothing to get");
        uint256 _userAmountBetWin = user_team_bet[msg.sender][teamWinner];

        for(uint256 i=1;i<=numberTeams;i++){
            delete user_team_bet[msg.sender][i];
        }

        myToken.transfer(walletTeam,_userReward*percentageTeam/100);
        myToken.transfer(walletCharity,_userReward*percentageCharity/100);
        myToken.burn(_userReward*percentageBurn/100);
        myToken.transfer(msg.sender,_userReward*(100-percentageTeam-percentageCharity-percentageBurn)/100);
        myToken.transfer(msg.sender,_userAmountBetWin);

        emit Claim(msg.sender, _userReward);
    }

}
