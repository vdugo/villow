// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract Bidding is AccessControl {
    bytes32 public constant SELLER_ROLE = keccak256("SELLER_ROLE");
    bytes32 public constant BUYER_ROLE = keccak256("BUYER_ROLE");

    struct Bid {
        address bidder;
        uint256 amount;
    }

    mapping(uint256 => Bid) highestBids;

    ERC721 public nftContract;

    constructor(address _nftContract) {
        _setupRole("DEFAULT_ADMIN_ROLE", msg.sender);
        nftContract = ERC721(_nftContract);
    }

    function placeBid(uint256 tokenId) public payable onlyRole(BUYER_ROLE) {}
}
