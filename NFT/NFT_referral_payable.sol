// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// Referral = NFT holder. NFT price: 1 ether. Commission split 90%/10% between referral and contract owner
contract NFT_referral_payable is Ownable, ERC721, ERC721Enumerable, ERC721URIStorage {

    using Counters for Counters.Counter;
    Counters.Counter public _tokenIdCounter;

    // NFT price
    uint256 public NFT_price;
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

    event Add_Whitelist(address[] listAddress);
    event Remove_Whitelist(address[] listAddress);

    constructor(string memory _ipfs) Ownable(msg.sender) ERC721("NFT Collection Name", "Ticker") {
        IPFS_URI=_ipfs;
        _safeMint(msg.sender, _tokenIdCounter.current());
        _tokenIdCounter.increment();
        NFT_price = 1 ether; // 1 ether
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
        // Commission split between referal and contract owner
        payable(input_referral).transfer(msg.value*90/100);
        payable(owner()).transfer(msg.value*10/100);
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

    function tokenURI(uint256 tokenId) public view ride(ERC721, ERC721URIStorage) returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
