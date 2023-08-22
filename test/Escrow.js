const { expect } = require('chai')
const { ethers, BigNumber } = require('hardhat')

const tokens = (number) => {
  return ethers.parseUnits(number.toString(), 'ether')
}

describe('Escrow', () => {
  // legalEntity will deploy the contracts
  let legalEntity

  // the rest of the roles
  let buyer, seller, appraiser, inspector, lender

  // contracts
  let property, escrow, bidding
  // 265 eth to wei about $500,000
  const priceInWei = ethers.parseEther('265')

  beforeEach(async () => {
    [legalEntity, buyer, seller, appraiser, inspector, lender] = await ethers.getSigners()

    property = await ethers.deployContract("Property", [])
    await property.waitForDeployment()

    escrow = await ethers.deployContract("Escrow", [property.getAddress(),
    appraiser.getAddress(),
    inspector.getAddress(),
    lender.getAddress()])
    await escrow.waitForDeployment()

    bidding = await ethers.deployContract("Bidding", [property.getAddress(), escrow.getAddress()])
    await bidding.waitForDeployment()

    // Now, set the Bidding contract's address in the Escrow contract
    await escrow.setBiddingContract(bidding.getAddress())
  })

  describe('Deployment', async () => {
    it('sets the Property ERC-721 Contract to the state', async () => {
      expect(await escrow.propertyContract()).to.equal(await property.getAddress())
    })
    it('sets the deployer of the Escrow contract as the legalEntity in the state', async () => {
      expect(await escrow.legalEntity()).to.equal(await legalEntity.getAddress())
    })
    it('sets the appraiser to the state', async () => {
      expect(await escrow.appraiser()).to.equal(await appraiser.getAddress())
    })
    it('sets the inspector to the state', async () => {
      expect(await escrow.inspector()).to.equal(await inspector.getAddress())
    })
    it('sets the lender to the state', async () => {
      expect(await escrow.lender()).to.equal(await lender.getAddress())
    })
  })

  describe('Listing properties', async () => {
    it('updates the state variable mappings when a listing is creating', async () => {

      let transaction = await property.connect(seller).setApprovalForAll(await escrow.getAddress(), true)
      await transaction.wait();
      transaction = await escrow.connect(seller).listProperty('TODO Implement URIs', priceInWei, false)
      await transaction.wait()

      expect(await property.tokenURI(1)).to.equal('TODO Implement URIs')
      expect(await escrow.propertyPrices(1)).to.equal(priceInWei)
      expect(await escrow.propertyApprovals(1)).to.equal(false)
      expect(await escrow.sellers(1)).to.equal(await seller.getAddress())
      // 1 is ForDirectSale in the PropertyStatuses enum
      expect(await escrow.propertyStatuses(1)).to.equal(1)
    })
  })

  describe('Legal Entity Approving Properties', async () => {
    it('updates the propertyApprovals mapping', async () => {
      let transaction = await escrow.connect(legalEntity).approveProperty(1)
      await transaction.wait()

      expect(await escrow.propertyApprovals(1)).to.equal(true)
    })
    it('only lets the legalEntity approve properties', async () => {
      await expect(escrow.connect(buyer).approveProperty(1)).to.be.reverted
      await expect(escrow.connect(seller).approveProperty(1)).to.be.reverted
      await expect(escrow.connect(appraiser).approveProperty(1)).to.be.reverted
      await expect(escrow.connect(inspector).approveProperty(1)).to.be.reverted
      await expect(escrow.connect(lender).approveProperty(1)).to.be.reverted
    })
    it('reverts if the property is already approved', async () => {
      let transaction = await escrow.connect(legalEntity).approveProperty(1)
      await transaction.wait()
      await expect(escrow.connect(legalEntity).approveProperty(1)).to.be.reverted
    })
  })

  describe('Buyer Payments', async () => {
    it('records the correct payment amount', async () => {
      await escrow.connect(seller).listProperty('TODO Implement URIs', priceInWei, false);
      await escrow.connect(legalEntity).approveProperty(1);
      await escrow.connect(buyer).buyerPayment(1, { value: priceInWei });

      expect(await escrow.paidAmounts(1)).to.equal(priceInWei);
    });

    it('records the buyer address', async () => {
      await escrow.connect(seller).listProperty('TODO Implement URIs', priceInWei, false);
      await escrow.connect(legalEntity).approveProperty(1);
      await escrow.connect(buyer).buyerPayment(1, { value: priceInWei });

      expect(await escrow.buyers(1)).to.equal(await buyer.getAddress());
    });

    it('refunds overpayment', async () => {
      const overpayAmount = priceInWei + BigInt(tokens(10).toString());

      await escrow.connect(seller).listProperty('TODO Implement URIs', priceInWei.toString(), false);
      await escrow.connect(legalEntity).approveProperty(1);

      const oldBalance = BigInt((await ethers.provider.getBalance(buyer.getAddress())).toString());
      const tx = await escrow.connect(buyer).buyerPayment(1, { value: overpayAmount.toString() });
      const gasUsed = BigInt((await tx.wait()).gasUsed.toString());
      const gasPrice = BigInt(tx.gasPrice.toString());

      // Ensure gasUsed and tx.gasPrice are also BigNumbers before arithmetic
      const gasCost = gasUsed * gasPrice;
      const expectedNewBalance = oldBalance - priceInWei - gasCost;

      const newBalance = BigInt((await ethers.provider.getBalance(buyer.getAddress())).toString());

      expect(newBalance.toString()).to.equal(expectedNewBalance.toString());
    });


  });

  describe('Finalizing sale of a DirectSale', async () => {
    it('only allows the legal entity to finalize the sale', async () => {
      await escrow.connect(seller).listProperty('TODO Implement URIs', priceInWei, false);
      await escrow.connect(legalEntity).approveProperty(1);
      await escrow.connect(buyer).buyerPayment(1, { value: priceInWei });

      await expect(escrow.connect(buyer).finalizeSale(1)).to.be.revertedWith("Only the legal entity can finalize the sale");
    });

    it('rejects finalize sale if payment not made', async () => {
      await escrow.connect(seller).listProperty('TODO Implement URIs', priceInWei, false);
      await escrow.connect(legalEntity).approveProperty(1);

      await expect(escrow.connect(legalEntity).finalizeSale(1)).to.be.revertedWith("Payment has not been made for this property");
    });
  });


})
