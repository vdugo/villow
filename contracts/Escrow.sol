// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./Property.sol";

contract Escrow {
    Property public propertyContract;
    address payable public seller;
    address public legalEntity;
    address public appraiser;
    address public inspector;
    address public lender;

    constructor(
        address _propertyContract,
        address payable _seller,
        address _legalEntity,
        address _appraiser,
        address _inspector,
        address _lender
    ) {
        propertyContract = Property(_propertyContract);
        seller = _seller;
        legalEntity = _legalEntity;
        appraiser = _appraiser;
        inspector = _inspector;
        lender = _lender;
    }

    function listProperty(string memory uri) public {
        // Minting a new NFT in the Property contract implies the listing of the property
        propertyContract.safeMint(msg.sender, uri);
    }

    function finalizeSale(uint256 tokenId) external {}
}
