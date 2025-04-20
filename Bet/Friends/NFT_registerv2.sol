// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// Register: enter a username and mint your free NFT.
contract NFT_registration is ERC721, ERC721Enumerable, ERC721URIStorage, Ownable  {

    using Counters for Counters.Counter;
    Counters.Counter public _tokenIdCounter;

    mapping (address => string) public user_username;
    mapping (string => address) public username_user;

    uint256 public count_ipfs = 0;
    mapping(uint256 => string) IPFS_URI;

    mapping(address=>uint256) public minted_Wallet;

    event Modify_IPFS(uint256 _num, string _ipfs);
    event Add_list_IPFS(string[] _ipfs);
    event Lower_Count_IPFS(uint256 _count);
    event Mint(address indexed _user);

    constructor() ERC721("Test Registration", "Test") Ownable(msg.sender) {
        _tokenIdCounter.increment();
    }

    function safeMint(uint256 IPFS_Id, string memory username) external {
        require(count_ipfs > 0, "no IPFS");
        require(IPFS_Id <= count_ipfs, "invalid IPFS ID");
        //Only 1 claim per wallet
        require(minted_Wallet[msg.sender] < 1, "exceeds max per wallet");
        require(username_user[username] == address(0), "username already choosen");
        bytes memory usernameBytes = bytes(username);
        require(usernameBytes.length <= 20 && usernameBytes.length > 2, "username invalid");

        for (uint256 i = 0; i < usernameBytes.length; i++) {
            if (
                usernameBytes[i] == ',' || 
                usernameBytes[i] == '"' || 
                usernameBytes[i] == "'" || 
                usernameBytes[i] == '@' || 
                usernameBytes[i] == '.' ||
                usernameBytes[i] == ':' ||
                usernameBytes[i] == '[' ||
                usernameBytes[i] == ']' || 
                usernameBytes[i] == '\\' || 
                usernameBytes[i] == '/'
            ) {
                revert("Username cannot contain a comma, single quote, double quote, @, ., :, [, ], \\ or /.");
            }
        }

        uint256 tokenId = _tokenIdCounter.current();
        _safeMint(msg.sender, tokenId);
        minted_Wallet[msg.sender]++;
        user_username[msg.sender] = username;
        username_user[username] = msg.sender;
        _setTokenURI(tokenId, IPFS_URI[IPFS_Id]);
        _tokenIdCounter.increment();
        
        emit Mint(msg.sender);
    }

    // Enter a list of IPFS URIs, the mapping starts at 1
    function add_list_IPFS(string[] memory _ipfs) external onlyOwner returns (bool) {

        for(uint i = 0; i < _ipfs.length; i++){
            count_ipfs++;
            IPFS_URI[count_ipfs] = _ipfs[i];
        }

        emit Add_list_IPFS(_ipfs);
        return true;
    }

    function modifyIPFS(uint256 _num, string memory _ipfs) external onlyOwner returns (bool) {
        require(_num <= count_ipfs && _num > 0, "number invalid");
        IPFS_URI[_num] = _ipfs;
        emit Modify_IPFS(_num, _ipfs);
        return true;
    }

    function lowerCountIPFS(uint256 _count) external onlyOwner returns (bool) {
        require(_count < count_ipfs, "number invalid");

        for(uint i = _count + 1; i <= count_ipfs; i++){
            delete IPFS_URI[i];
        }
        
        count_ipfs = _count;
        return true;
    }

    function getAlias(address _user) external view returns (string memory) {
        return user_username[_user];
    }

    function getAddressAlias(string memory _alias) external view returns (address) {
        return username_user[_alias];
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