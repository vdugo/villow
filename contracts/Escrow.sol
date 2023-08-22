// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./Property.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./Bidding.sol";

contract Escrow is AccessControl {
    // buyers and sellers will be message senders
    Property public propertyContract;
    Bidding public biddingContract;
    address public legalEntity;
    address public appraiser;
    address public inspector;
    address public lender;

    bytes32 public constant LEGAL_ENTITY_ROLE = keccak256("LEGAL_ENTITY_ROLE");

    // tokenId => is approved by legal entity or not
    mapping(uint256 => bool) public propertyApprovals;
    // tokenId => seller
    mapping(uint256 => address payable) public sellers;
    // tokenId => price
    mapping(uint256 => uint256) public propertyPrices;
    // tokenId => PropertyStatus
    mapping(uint256 => PropertyStatus) public propertyStatuses;

    // tokenId => buyer address
    mapping(uint256 => address) public buyers;
    // tokenId => paid amount by buyer
    mapping(uint256 => uint256) public paidAmounts;

    // tokenId => appraiser
    mapping(uint256 => uint256) public appraisedValues;
    // tokenId => inspector has approved
    mapping(uint256 => bool) public inspectorApprovals;
    // tokenId => lender has approved loan
    mapping(uint256 => bool) public lenderApprovals;

    // Define an enum for the sales status of each property
    enum PropertyStatus {
        NotForSale,
        ForSaleDirect,
        BiddingNotStarted,
        BiddingActive,
        BiddingEnded
    }

    constructor(
        address _propertyContract,
        address _appraiser,
        address _inspector,
        address _lender,
        address _biddingContract
    ) {
        propertyContract = Property(_propertyContract);
        legalEntity = msg.sender;
        appraiser = _appraiser;
        inspector = _inspector;
        lender = _lender;
        biddingContract = Bidding(_biddingContract);

        _setupRole(LEGAL_ENTITY_ROLE, msg.sender);
    }

    function listProperty(
        string memory uri,
        uint256 price,
        bool forAuction
    ) public {
        require(bytes(uri).length > 0, "URI cannot be null");
        require(price > 0, "price must be greater than 0");
        // Minting a new NFT in the Property contract implies the listing of the property
        uint256 newPropertyId = propertyContract.safeMint(msg.sender, uri);

        sellers[newPropertyId] = payable(msg.sender);
        propertyPrices[newPropertyId] = price;

        // Start the property off as unapproved
        propertyApprovals[newPropertyId] = false;

        // Check if the seller wants Bidding (auction) or not
        if (forAuction) {
            propertyStatuses[newPropertyId] = PropertyStatus.BiddingNotStarted;
        } else {
            propertyStatuses[newPropertyId] = PropertyStatus.ForSaleDirect;
        }
    }

    function approveProperty(
        uint256 tokenId
    ) public onlyRole(LEGAL_ENTITY_ROLE) {
        require(
            propertyApprovals[tokenId] == false,
            "Property is already approved"
        );
        propertyApprovals[tokenId] = true;
    }

    function buyerPayment(uint256 tokenId) external payable {
        require(
            propertyApprovals[tokenId] == true,
            "Property is not approved by Legal Entity"
        );
        require(
            propertyStatuses[tokenId] == PropertyStatus.ForSaleDirect ||
                propertyStatuses[tokenId] == PropertyStatus.BiddingEnded,
            "Property must be for DirectSale or bidding must have ended on the property"
        );

        // Check if the buyer has sent enough funds
        require(
            msg.value >= propertyPrices[tokenId],
            "The amount sent is not enough for the property"
        );

        // Record the payment amount
        paidAmounts[tokenId] = propertyPrices[tokenId];

        // Record the buyer's address
        buyers[tokenId] = msg.sender;

        // check if the buyer overpaid and refund
        if (msg.value > propertyPrices[tokenId]) {
            uint256 excessAmount = msg.value - propertyPrices[tokenId];
            payable(msg.sender).transfer(excessAmount);
        }
    }

    function finalizeSale(uint256 tokenId) external payable {
        require(
            msg.sender == legalEntity,
            "Only the legal entity can finalize the sale"
        );
        require(
            paidAmounts[tokenId] >= propertyPrices[tokenId],
            "Payment has not been made for this property"
        );

        // Transfer the NFT from the seller to the buyer
        propertyContract.safeTransferFrom(
            sellers[tokenId],
            buyers[tokenId],
            tokenId
        );

        // Send the funds to the seller
        sellers[tokenId].transfer(paidAmounts[tokenId]);

        // Update the status of the property
        propertyStatuses[tokenId] = PropertyStatus.NotForSale;

        // After a property is sold, it should not remain approved
        propertyApprovals[tokenId] = false;

        // Clear payment and buyer mappings
        paidAmounts[tokenId] = 0;
        buyers[tokenId] = address(0);
    }

    function startBidding(uint256 tokenId, uint256 customDuration) external {
        require(propertyApprovals[tokenId], "Property not approved");
        require(
            propertyStatuses[tokenId] == PropertyStatus.BiddingNotStarted,
            "Bidding already started or not applicable"
        );

        propertyStatuses[tokenId] = PropertyStatus.BiddingActive;

        // Default duration for the bid (7 days in seconds)
        uint256 duration = 24 * 60 * 60; // equals 86,400 seconds or 7 days

        if (customDuration != 0) {
            duration = customDuration;
        }

        // Initiate bidding in the Bidding contract with the duration
        biddingContract.initiateBidding(tokenId, duration);
    }

    // Proxy function to place a bid
    function placeBid(uint256 tokenId) external payable {
        // Ensure the property is currently in the bidding phase
        require(
            propertyStatuses[tokenId] == PropertyStatus.BiddingActive,
            "Bidding is not active for this property"
        );

        // Forward the received funds and call the placeBid function in Bidding.sol
        // The 'call' function here will forward all available gas and funds to the function in the Bidding contract.
        // This ensures that the bid function has enough gas to execute and the msg.value is sent as well.
        (bool success, ) = address(biddingContract).call{value: msg.value}(
            abi.encodeWithSignature("placeBid(uint256)", tokenId)
        );

        // Check if the function call was successful
        require(success, "Bid placement failed");
    }

    function endBidding(uint256 tokenId) external {
        // Logic to check the sender's permissions if needed

        uint256 finalBidAmount = biddingContract.finalizeBidding(tokenId);
        propertyStatuses[tokenId] = PropertyStatus.BiddingEnded;
        propertyPrices[tokenId] = finalBidAmount; // Set the final sale price based on the highest bid
    }
}
