// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// Register: enter a username and mint your free NFT
contract NFT_registration is ERC721, ERC721Enumerable, ERC721URIStorage, Ownable  {

    using Counters for Counters.Counter;
    Counters.Counter public _tokenIdCounter;

    mapping (address => string) public user_username;
    mapping (string => address) public username_user;

    uint256 public count_ipfs=0;
    mapping(uint256 => string) IPFS_URI;

    mapping(address=>uint256) public minted_Wallets;

    event Modify_IPFS(uint256 _num, string _ipfs);
    event Add_list_IPFS(string[] _ipfs);
    event Lower_Count_IPFS(uint256 _count);

    constructor() ERC721("NFT Collection Name", "Ticker") Ownable(msg.sender) {
        _tokenIdCounter.increment();
    }

    function safeMint(uint256 IPFS_Id, string memory username) public {
        require(count_ipfs>0,"no IPFS");
        require(IPFS_Id<=count_ipfs,"invalid IPFS ID");
        //1 claim per wallet
        require(minted_Wallets[msg.sender]<1,"exceeds max per wallet");
        require(bytes(username).length<=20 && bytes(username).length>2,"username invalid");
        require(username_user[username]==address(0),"username already choosen");
        uint256 tokenId = _tokenIdCounter.current();
        _safeMint(msg.sender, tokenId);
        minted_Wallets[msg.sender]++;
        user_username[msg.sender]=username;
        username_user[username]=msg.sender;
        _setTokenURI(tokenId, IPFS_URI[IPFS_Id]);
        _tokenIdCounter.increment();
    }

    function change_username(string memory new_username) public {
        require(bytes(new_username).length<=20 && bytes(new_username).length>2,"username invalid");
        require(minted_Wallets[msg.sender]>0,"register first!");
        require(username_user[new_username]==address(0),"username already choosen");
        delete username_user[user_username[msg.sender]];
        user_username[msg.sender]=new_username;
        username_user[new_username]=msg.sender;
    }

    // enter a list of IPFS URI
    function add_list_IPFS(string[] memory _ipfs) onlyOwner public returns (bool) {
        for(uint i=0;i<_ipfs.length;i++){
            count_ipfs++;
            IPFS_URI[count_ipfs]=_ipfs[i];
        }
        emit Add_list_IPFS(_ipfs);
        return true;
    }

    function modifyIPFS(uint256 _num, string memory _ipfs) onlyOwner public returns (bool) {
        require(_num<=count_ipfs && _num>0, "number invalid");
        IPFS_URI[_num]=_ipfs;
        emit Modify_IPFS(_num,_ipfs);
        return true;
    }

    function lowerCountIPFS(uint256 _count) onlyOwner public returns (bool) {
        require(_count<count_ipfs, "number invalid");
        for(uint i=_count+1;i<=count_ipfs;i++){
            delete IPFS_URI[i];
        }
        count_ipfs=_count;
        return true;
    }

    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Enumerable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._increaseBalance(account, value);
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
        override(ERC721, ERC721Enumerable, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

}
