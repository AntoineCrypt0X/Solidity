// SPDX-License-Identifier: MIT
// An example of a consumer contract that relies on a subscription for funding.
pragma solidity 0.8.20;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts@1.2.0/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts@1.2.0/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
    Lottery: ticket=0.01 ether. A random number is drawn to set the winner
 */

contract Raffle is VRFConsumerBaseV2Plus {

    address payable[] public players;
    uint256 public lotteryId;
    mapping (uint256 => address payable) public lotteryHistory;

    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);

    struct RequestStatus {
        bool fulfilled; // whether the request has been successfully fulfilled
        bool exists; // whether a requestId exists
        uint256[] randomWords;
    }
    mapping(uint256 => RequestStatus) public s_requests; /* requestId --> requestStatus */

    // Your subscription ID.
    uint256 public s_subscriptionId;

    // Past request IDs.
    uint256[] public requestIds;
    uint256 public lastRequestId;

    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/docs/vrf/v2-5/supported-networks
    bytes32 public keyHash = 0x719ed7d7664abc3001c18aac8130a2265e1e70b7e036ae20f3ca8b92b3154d86;

    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Storing each word costs about 20,000 gas,
    // so 100,000 is a safe default for this example contract. Test and adjust
    // this limit based on the network that you select, the size of the request,
    // and the processing of the callback request in the fulfillRandomWords()
    // function.
    uint32 public callbackGasLimit = 600000;

    // The default is 3, but you can set this higher.
    uint16 public requestConfirmations = 3;

    // For this example, retrieve 2 random values in one request.
    // Cannot exceed VRFCoordinatorV2_5.MAX_NUM_WORDS.
    uint32 public numWords = 1;

    /**
     * HARDCODED FOR SEPOLIA
     * COORDINATOR: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B
     */
    constructor(uint256 subscriptionId) VRFConsumerBaseV2Plus(0xec0Ed46f36576541C75739E915ADbCb3DE24bD77) {
        s_subscriptionId = subscriptionId;
        lotteryId = 1;
    }

    function getWinnerByLottery(uint lottery) public view returns (address payable) {
        return lotteryHistory[lottery];
    }

    function getBalance() public view returns (uint) {
        return address(this).balance;
    }

    function getPlayers() public view returns (address payable[] memory) {
        return players;
    }

    function enter() public payable {
        require(msg.value == .01 ether);

        // address of player entering lottery
        players.push(payable(msg.sender));
    }

    function pickWinner(uint256 _randomNumber) internal {
        uint256 index = _randomNumber % players.length;
        players[index].transfer(address(this).balance);

        lotteryHistory[lotteryId] = players[index];
        lotteryId++;
        
        // reset the state of the contract
        players = new address payable[](0);
    }

    // Assumes the subscription is funded sufficiently.
    // @param enableNativePayment: Set to `true` to enable payment in native tokens, or
    // `false` to pay in LINK
    function requestRandomWords(
        bool enableNativePayment
    ) external onlyOwner returns (uint256 requestId) {
        // Will revert if subscription is not set and funded.
        requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: keyHash,
                subId: s_subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: numWords,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({
                        nativePayment: enableNativePayment
                    })
                )
            })
        );
        s_requests[requestId] = RequestStatus({
            randomWords: new uint256[](0),
            exists: true,
            fulfilled: false
        });
        requestIds.push(requestId);
        lastRequestId = requestId;
        emit RequestSent(requestId, numWords);
        return requestId;
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] calldata _randomWords
    ) internal override {
        require(s_requests[_requestId].exists, "request not found");
        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomWords;
        pickWinner(_randomWords[0]);
        emit RequestFulfilled(_requestId, _randomWords);
    }

    function getRequestStatus(
        uint256 _requestId
    ) external view returns (bool fulfilled, uint256[] memory randomWords) {
        require(s_requests[_requestId].exists, "request not found");
        RequestStatus memory request = s_requests[_requestId];
        return (request.fulfilled, request.randomWords);
    }
}
