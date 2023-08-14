// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./Property.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "hardhat/console.sol";

contract Escrow is AccessControl {
    // buyers and sellers will be message senders
    Property public propertyContract;
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
        address _lender
    ) {
        propertyContract = Property(_propertyContract);
        legalEntity = msg.sender;
        appraiser = _appraiser;
        inspector = _inspector;
        lender = _lender;

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

        // check if the buyer overpaid
        if (msg.value > propertyPrices[tokenId]) {
            uint256 excessAmount = msg.value - propertyPrices[tokenId];
            payable(msg.sender).transfer(excessAmount);
        }

        // Record the payment amount
        paidAmounts[tokenId] = propertyPrices[tokenId];

        // Record the buyer's address
        buyers[tokenId] = msg.sender;
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
}
