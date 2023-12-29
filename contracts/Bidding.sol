// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./Property.sol";
import "./Escrow.sol";

contract Bidding {
    // The property contract reference
    Property public propertyContract;
    Escrow public escrowContract;

    // tokenId => highest bid
    mapping(uint256 => uint256) public highestBids;

    // tokenId => highest bidder
    mapping(uint256 => address) public highestBidders;

    // tokenId => end time of bid
    mapping(uint256 => uint256) public bidEndTimes;

    // Events
    event BidPlaced(
        uint256 indexed tokenId,
        address indexed bidder,
        uint256 value
    );

    constructor(address _propertyContract, address _escrowContract) {
        propertyContract = Property(_propertyContract);
        escrowContract = Escrow(_escrowContract);
    }

    modifier onlyEscrow() {
        require(
            msg.sender == address(escrowContract),
            "Only the Escrow contract can call this."
        );
        _;
    }

    function initiateBidding(
        uint256 tokenId,
        uint256 duration
    ) external onlyEscrow {
        bidEndTimes[tokenId] = block.timestamp + duration;
    }

    function placeBid(uint256 tokenId) external payable {
        require(bidEndTimes[tokenId] > block.timestamp, "Bidding has ended.");

        uint256 refundAmount = highestBids[tokenId];
        address previousBidder = highestBidders[tokenId];

        // If the bidder is the current highest bidder, only require them to outbid themselves.
        // Otherwise, the new bidder should outbid the current highest bid.
        if (msg.sender == highestBidders[tokenId]) {
            require(
                msg.value + highestBids[tokenId] > highestBids[tokenId],
                "Combined bid must exceed the current bid."
            );
            highestBids[tokenId] += msg.value;
        } else {
            require(
                msg.value > highestBids[tokenId],
                "There's already a higher bid."
            );
            highestBids[tokenId] = msg.value;
            highestBidders[tokenId] = msg.sender;
        }

        emit BidPlaced(tokenId, msg.sender, highestBids[tokenId]);

        // Refund the old highest bidder if there was one and the current sender isn't the previous bidder
        if (refundAmount > 0 && msg.sender != previousBidder) {
            payable(previousBidder).transfer(refundAmount);
        }
    }

    function finalizeBidding(
        uint256 tokenId
    ) external onlyEscrow returns (uint256) {
        require(
            bidEndTimes[tokenId] < block.timestamp,
            "Bidding has not ended yet."
        );

        uint256 paymentAmount = highestBids[tokenId];

        // Reset highest bids and bidders first
        highestBids[tokenId] = 0;
        highestBidders[tokenId] = address(0);

        // Forward the payment
        escrowContract.buyerPayment{value: paymentAmount}(tokenId);

        return paymentAmount;
    }
}
