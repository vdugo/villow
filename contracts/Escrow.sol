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

    function listProperty(string memory uri) public {
        // Minting a new NFT in the Property contract implies the listing of the property
        uint256 newPropertyId = propertyContract.safeMint(msg.sender, uri);

        sellers[newPropertyId] = payable(msg.sender);

        // Start the property off as unapproved
        propertyApprovals[newPropertyId] = false;
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

    function finalizeSale(uint256 tokenId) external {
        require(propertyApprovals[tokenId] == true, "Property is not approved");
    }
}
