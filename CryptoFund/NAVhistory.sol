// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./fund.sol";


contract NAV is Ownable {

    struct NAVRecord {
        uint256 timestamp;
        uint256 totalValue;
    }

    address public fund_address;
    Fund10 public immutable fund;

    constructor(address _fund_address) Ownable(msg.sender) {
        fund = Fund10(_fund_address);
    }

    function getNAV() view public returns (NAVRecord memory) {
        Fund10.NAVRecord memory externalNav = fund.getLastNAV();
        return NAVRecord({
            timestamp: externalNav.timestamp,
            totalValue: externalNav.totalValue
        });
    }

    function getNAVvalue() view public returns (uint256) {
        Fund10.NAVRecord memory externalNav = fund.getLastNAV();
        return externalNav.totalValue;
    }

    function NAVatIndex(uint256 index) external view returns (NAVRecord memory) {
        Fund10.NAVRecord memory externalNav = fund.NAVatIndex(index);
        return NAVRecord({
            timestamp: externalNav.timestamp,
            totalValue: externalNav.totalValue
        });
    }

    function NAVatIndexValue(uint256 index) external view returns (uint256) {
        Fund10.NAVRecord memory externalNav = fund.NAVatIndex(index);
        return externalNav.totalValue;
    }

    function buildNAVHistory(uint256 periode) external view returns (NAVRecord[] memory){
        uint256 last_index = fund.id_time();
        require(periode <= last_index, "Not enough history");
        
        NAVRecord[] memory fund_histo = new NAVRecord[](periode);
        Fund10.NAVRecord memory externalNav;
        NAVRecord memory record;

        for (uint256 i = 0; i < periode; i++) {
            externalNav = fund.NAVatIndex(last_index - periode + i + 1);
            record = NAVRecord({
                timestamp: externalNav.timestamp,
                totalValue: externalNav.totalValue
            });
            fund_histo[i] = record;
        }
        return fund_histo;
    }

    function getNAVValuesAndTimestamps(uint256 periode) external view returns (uint256[] memory values, uint256[] memory timestamps) {
        uint256 last_index = fund.id_time();
        require(periode <= last_index, "Not enough history");

        values = new uint256[](periode);
        timestamps = new uint256[](periode);

        Fund10.NAVRecord memory externalNav;

        for (uint256 i = 0; i < periode; i++) {
            externalNav = fund.NAVatIndex(last_index - periode + i + 1);
            values[i] = externalNav.totalValue;
            timestamps[i] = externalNav.timestamp;
        }
    }

}