// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./IERC20.sol";

// Waiting for Hyperliq Testnet
interface L1Read {
    function spotPxs(address token) external view returns (uint256); // Spot Price
    function spotBalance(address user, address token) external view returns (uint256); // Balance
}

interface L1Write {
    function sendIocOrder(address asset, bool isBuy, uint256 sz) external; //Market Buy
    function sendCDeposit(uint256 _wei) external;
    function sendCWithdrawal(uint256 _wei) external;
}

contract Fund10 is Ownable {

    L1Read constant l1Read = L1Read(0x1111111111111111111111111111111111111111);
    L1Write constant l1Write = L1Write(0x3333333333333333333333333333333333333333);

    address[10] public assets; // Oracle feed per asset
    uint256[10] public weights;
    uint256 public total_shares;
    uint256 public totalFundValueUSD ; // NAV
    uint256 public id_time;
    address public usdt;
    bool public paused = false;

    mapping(address => uint256) public userShares;
    // NAV history
    mapping(uint256 => NAVRecord) public NAVHistory;

    struct InvestmentEntry {
        uint256 timestamp;
        uint256 amountUSD;
        uint256 sharesIssued;
        address user;
    }

    struct InvestmentExit {
        uint256 timestamp;
        uint256 amountUSD;
        uint256 sharesOut;
        address user;
    }

    struct NAVRecord {
        uint256 timestamp;
        uint256 totalValue;
    }

    mapping(uint256 => InvestmentEntry) public histo_entry;
    mapping(uint256 => InvestmentExit) public histo_exit;

    uint256 public index_entry;
    uint256 public index_exit;

    modifier updateFundValueUSD() {
        updateFundNAV();
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    event AssetsUpdated(address[10] newAssets);
    event WeightsUpdated(uint256[10] newWeights);
    event NAVUpdated(uint256 value, uint256 timestamp);
    event Entry(address user, uint256 amountUSD, uint256 timestamp);
    event Exit(address user, uint256 amountUSD, uint256 timestamp);

    constructor(address[] memory _assets, uint256[] memory _weights, address _usdt) Ownable(msg.sender) {
        require(_assets.length == 10, "Exactly 10 assets required");
        require(_weights.length == 10, "Exactly 10 weights required");

        uint256 total = 0;
        for (uint256 i = 0; i < 10; i++) {
            total += _weights[i];
        }
        require(total == 10000, "Weights must sum to 10000");

        for (uint256 i = 0; i < 10; i++) {
            assets[i] = _assets[i];
            weights[i] = _weights[i];
        }

        usdt = _usdt;
    }

    function setAssets(address[] memory _assets) external onlyOwner {
        require(_assets.length == 10, "Exactly 10 assets required");

        for (uint256 i = 0; i < 10; i++) {
            assets[i] = _assets[i];
        }

        emit AssetsUpdated(assets);
    }

    function setWeights(uint256[] memory _weights) external onlyOwner {
        require(_weights.length == 10, "Exactly 10 weights required");

        uint256 total = 0;
        for (uint256 i = 0; i < 10; i++) {
            total += _weights[i];
        }
        require(total == 10000, "Weights must sum to 10000");

        for (uint256 i = 0; i < 10; i++) {
            weights[i] = _weights[i];
        }

        emit WeightsUpdated(weights);
    }

    function getAssets() external view returns (address[10] memory) {
        return assets;
    }

    function getWeights() external view returns (uint256[10] memory) {
        return weights;
    }

    // Get the latest price from Chainlink oracle
    function getLatestPrice(address feeds) public view returns (uint256) {
        require(feeds != address(0), "No feed for asset");
        AggregatorV3Interface feed = AggregatorV3Interface(feeds);
        (, int price, , ,) = feed.latestRoundData();
        require(price > 0, "Invalid price");
        return uint256(price*10**10); // Decimal 8 + 10 = 18
    }

    function getNAV() public view returns (uint256 navUSD) {
        for (uint i = 0; i < 10; i++) {
            uint256 balance = l1Read.spotBalance(address(this), assets[i]);
            uint256 price = getLatestPrice(assets[i]); // ex: 18 décimales
            navUSD += (balance * price) / 1e18;
        }
    }

    function updateFundNAV() internal {
        uint256 navUSD = getNAV();
        totalFundValueUSD = navUSD;
        id_time += 1;
        NAVHistory[id_time] = NAVRecord({
            timestamp: block.timestamp,
            totalValue: navUSD
        });

        emit NAVUpdated(navUSD, block.timestamp);
    }

    function triggerUpdateNAV() external onlyOwner {
        updateFundNAV();
    }

    function getLastNAV() external view returns (NAVRecord memory) {
        return NAVHistory[id_time];
    }

    function getLastNAVvalue() external view returns (uint256) {
        return NAVHistory[id_time].totalValue;
    }

    function NAVatIndex(uint256 index) external view returns (NAVRecord memory) {
        return NAVHistory[index];
    }

    function NAVatIndexValue(uint256 index) external view returns (uint256) {
        return NAVHistory[index].totalValue;
    }

    function getSharePrice() public view returns (uint256) {
        require(total_shares > 0, "No shares issued");
        return totalFundValueUSD * 1e18 / total_shares;
    }

    // Still to be developed: handle the deposit timing from the smart contract to the Hyperliq account, and then placing the orders.
    function fundEntry(uint256 _amountUSD) whenNotPaused updateFundValueUSD() external {
        require(_amountUSD > 0, "Amount must be > 0");

        bool success = IERC20(usdt).transferFrom(msg.sender, address(this), _amountUSD);
        require(success, "Transfer failed");

        // Apply entry fee of 0.3% and send it to contract owner
        uint256 fee = (_amountUSD * 3) / 1000;
        uint256 amountAfterFee = _amountUSD - fee;

        success = IERC20(usdt).transfer(owner(), fee);
        require(success, "Fee transfer failed");

        // Deposit only the net amount (after fee) to Hyperliq
        l1Write.sendCDeposit(amountAfterFee);

        uint256 new_shares = total_shares == 0 
            ? amountAfterFee 
            : (amountAfterFee * total_shares) / totalFundValueUSD;

        userShares[msg.sender] += new_shares;
        total_shares += new_shares;

        for (uint256 i = 0; i < assets.length; i++) {
            address token = assets[i];
            uint256 wgt = weights[i];
            uint256 size = (amountAfterFee * wgt) / 10000;
            if (wgt > 0) {
                l1Write.sendIocOrder(token, true, size);
            }
        }

        index_entry += 1;
        InvestmentEntry memory new_entry = InvestmentEntry({
            timestamp: block.timestamp,
            amountUSD: amountAfterFee,
            sharesIssued: new_shares,
            user: msg.sender
        });

        histo_entry[index_entry] = new_entry;

        emit Entry(msg.sender, amountAfterFee, block.timestamp);
    }


    // Still to be developed: handle the withdrawal timing from the Hyperliq account to the smart contract,
    // and then from the smart contract to the user.
    function fundExit(uint256 _shares) updateFundValueUSD() external {
        require(_shares > 0, "Must withdraw some shares");
        require(userShares[msg.sender] >= _shares, "Not enough shares");

        uint256 amountUSD = (_shares * totalFundValueUSD) / total_shares;

        userShares[msg.sender] -= _shares;
        total_shares -= _shares;

        for (uint256 i = 0; i < 10; i++) {
            address token = assets[i];
            uint256 wgt = weights[i];
            if (wgt > 0) {
                uint256 size = (amountUSD * wgt) / 10000;
                l1Write.sendIocOrder(token, false, size);
            }
        }

        l1Write.sendCWithdrawal(amountUSD); 
        
        bool success = IERC20(usdt).transfer(msg.sender, amountUSD);
        require(success);

        index_exit += 1;
        InvestmentExit memory new_exit = InvestmentExit({
            timestamp: block.timestamp,
            amountUSD: amountUSD,
            sharesOut: _shares,
            user: msg.sender
        });

        histo_exit[index_exit] = new_exit;

        emit Exit(msg.sender, amountUSD, block.timestamp);
    }

    function rebalance() external onlyOwner updateFundValueUSD {
        uint256 nav = totalFundValueUSD;

        for (uint256 i = 0; i < 10; i++) {
            uint256 weight = weights[i];
            if (weight == 0) continue;

            address asset = assets[i];
            uint256 balance = l1Read.spotBalance(address(this), asset);
            uint256 price = getLatestPrice(asset);
            uint256 currentValue = (balance * price) / 1e18;

            uint256 targetValue = (nav * weight) / 10000;

            // If within 1% tolerance, skip
            uint256 delta = targetValue > currentValue ? targetValue - currentValue : currentValue - targetValue;
            if (delta * 10000 / nav < 100) {
                continue; // skip if <1% deviation
            }

            if (currentValue < targetValue) {
                // Need to buy more of this asset
                uint256 usdToBuy = targetValue - currentValue;
                l1Write.sendIocOrder(assets[i], true, uint64(usdToBuy));
            } else {
                // Need to sell excess
                uint256 usdToSell = currentValue - targetValue;
                l1Write.sendIocOrder(assets[i], false, uint64(usdToSell));
            }
        }
    }


    function pause() external onlyOwner {
    paused = true;
    }

    function unpause() external onlyOwner {
        paused = false;
    }
}
