const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('Bidding', () => {
  let legalEntity, buyer, seller, appraiser, inspector, lender;
  let property, escrow, bidding;

  const priceInWei = ethers.parseEther('265');

  beforeEach(async () => {
    [legalEntity, buyer, seller, appraiser, inspector, lender] = await ethers.getSigners();

    property = await ethers.deployContract("Property", []);
    await property.waitForDeployment();

    escrow = await ethers.deployContract("Escrow", [
      property.getAddress(),
      appraiser.getAddress(),
      inspector.getAddress(),
      lender.getAddress()
    ]);
    await escrow.waitForDeployment();

    bidding = await ethers.deployContract("Bidding", [property.getAddress(), escrow.getAddress()]);
    await bidding.waitForDeployment();

    await escrow.setBiddingContract(bidding.getAddress());
  });

  describe('Deployment', async () => {
    it('sets the Property ERC-721 Contract to the state', async () => {
      expect(await bidding.propertyContract()).to.equal(await property.getAddress());
    });

    it('sets the Escrow contract address to the state', async () => {
      expect(await bidding.escrowContract()).to.equal(await escrow.getAddress());
    });
  });

  const { expect } = require('chai');

  describe('Bid Creation', () => {
    it('allows a buyer to create a bid via the Escrow contract', async () => {
      // Assuming a property has been listed for bidding
      await escrow.connect(seller).listProperty('URI_for_property', priceInWei, true);
      await escrow.connect(legalEntity).approveProperty(1);
      await escrow.connect(seller).startBidding(1, 0);  // Use default duration

      // Buyer places a bid
      const bidAmount = ethers.parseEther('250');
      await escrow.connect(buyer).placeBid(1, { value: bidAmount });

      const highestBid = await bidding.highestBids(1);

      expect(highestBid).to.equal(bidAmount);
    });

    it('prevents bids on non-approved properties', async () => {
      // Property is listed but not approved by legal entity
      await escrow.connect(seller).listProperty('URI_for_property', priceInWei, true);

      const bidAmount = ethers.parseEther('250');

      await expect(escrow.connect(buyer).placeBid(1, { value: bidAmount }))
        .to.be.revertedWith("Bidding is not active for this property");
    });

    it('ensures multiple bids from the same buyer updates the bid', async () => {
      await escrow.connect(seller).listProperty('URI_for_property', priceInWei, true);
      await escrow.connect(legalEntity).approveProperty(1);
      await escrow.connect(seller).startBidding(1, 0);  // Use default duration

      const initialBidAmount = ethers.parseEther('240');
      await escrow.connect(buyer).placeBid(1, { value: initialBidAmount });

      // Now only send the difference for the updated bid
      const additionalBidAmount = ethers.parseEther('15'); // This is 255 - 240
      await escrow.connect(buyer).placeBid(1, { value: additionalBidAmount });

      const highestBid = await bidding.highestBids(1);

      // Expecting the highest bid to be 255
      const expectedBid = ethers.parseEther('255');
      expect(highestBid).to.equal(expectedBid);
    });
  });



});
