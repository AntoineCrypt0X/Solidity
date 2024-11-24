// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// Referral = NFT holder. NFT price: 1 ether. Commission split between referral tree and contract owner
contract NFT_referral_payable is Ownable, ERC721, ERC721Enumerable, ERC721URIStorage {

    using Counters for Counters.Counter;
    Counters.Counter public _tokenIdCounter;

    // NFT price
    uint256 public NFT_price;
    // Number of levels of the referral tree
    uint256 public max_levels_referral;
    // mapping user -> referral
    mapping ( address => address ) public  referral_users;
    // mapping user -> whitelist
    mapping(address=>  bool) public whitelist_address;
    // mapping user -> username
    mapping (address => string) public username_dapp;
    // IPFS URI
    string public IPFS_URI;
    // mapping user -> NFT minted
    mapping(address=>uint256) public minted_Wallets;
    // mapping level commission
    mapping (uint256 => uint256) public commission_Levels;

    event Add_Whitelist(address[] listAddress);
    event Remove_Whitelist(address[] listAddress);

    constructor(string memory _ipfs) Ownable(msg.sender) ERC721("NFT Collection Name", "Ticker") {
        IPFS_URI=_ipfs;
        _safeMint(msg.sender, _tokenIdCounter.current());
        whitelist_address[msg.sender]=True;
        _tokenIdCounter.increment();
        NFT_price = 1 ether; // 1 ether
        max_levels_referral=3;
        Levels[1]=50;
        Levels[2]=25;
        Levels[3]=15;
    }

    function add_whitelist(address[] memory listAddress) onlyOwner public returns (bool) {
        for(uint i=0;i<listAddress.length;i++){
            whitelist_address[listAddress[i]]=true;
        }
        emit Add_Whitelist(listAddress);
        return true;
    }

    function remove_whitelist(address[] memory listAddress) onlyOwner public returns (bool) {
        for(uint i=0;i<listAddress.length;i++){
            delete whitelist_address[listAddress[i]];
        }
        emit Remove_Whitelist(listAddress);
        return true;
    }

    function getChainParent(address user) public view returns(address[] memory){
        uint256 count=1;
        address[] memory listParents= new address[](uint256(max_levels_referral));
        address Parent=referral_users[user];
        while(count <= max_levels_referral && Parent != address(0)){
            listParents[uint256(count-1)]=Parent;
            Parent=referral_users[Parent];
            count++;
        }
        return listParents;
    }

    function safeMint(address input_referral, string memory username) payable public {
        require(msg.value== NFT_price,"wrong value sent");
        require(whitelist_address[msg.sender],"Address not whitelisted");
        uint256 tokenId = _tokenIdCounter.current();
        // 1 claim per wallet
        require(minted_Wallets[msg.sender]<1,"exceeds max per wallet");
        require(balanceOf(input_referral)>0,"Referral not valid");
        _safeMint(msg.sender, tokenId);
        minted_Wallets[msg.sender]++;
        referral_users[msg.sender]=input_referral;
        username_dapp[msg.sender]=username;
        _setTokenURI(tokenId, IPFS_URI);
        _tokenIdCounter.increment();
        // Commission split between referrals and contract owner
        uint256 commission_count=100;
        uint256 level=1;
        address Parent;
        address[] memory parents=getNFTreferrals(input_referral);
        if (parents.length>0){
            Parent=parents[0];
            while(level <= max_levels && Parent != address(0))
            {
                payable(Parent).transfer(msg.value*commission_Levels[level]/100);
                commission_count-=Levels[level];
                if (level <= max_levels-1){
                    Parent=parents[level];
                }
                level++;
            }
        }
        // the rest is sent to the contract owner
        payable(owner()).transfer(msg.value*commission_count/100);
    }

    function modifyIPFS(string memory _ipfs) onlyOwner public returns (bool) {
        IPFS_URI=_ipfs;
        return true;
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
