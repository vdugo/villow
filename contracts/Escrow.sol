// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

contract Escrow {
    address public nftAddress;
    address payable public seller;
    address public legalEntity;
    address public appraiser;
    address public inspector;
    address public lender;

    constructor(
        address _nftAddress,
        address payable _seller,
        address _legalEntity,
        address _appraiser,
        address _inspector,
        address _lender
    ) {
        nftAddress = _nftAddress;
        seller = _seller;
        legalEntity = _legalEntity;
        appraiser = _appraiser;
        inspector = _inspector;
        lender = _lender;
    }
}
