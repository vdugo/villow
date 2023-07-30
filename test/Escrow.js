const { expect } = require('chai')
const { ethers } = require('hardhat')

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

    escrow.waitForDeployment()

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
      let transaction = await escrow.connect(seller).listProperty('TODO Implement URIs', priceInWei)
      await transaction.wait()

      expect(await property.tokenURI(1)).to.equal('TODO Implement URIs')
      expect(await escrow.propertyPrices(1)).to.equal(priceInWei)
      expect(await escrow.propertyApprovals(1)).to.equal(false)
      expect(await escrow.sellers(1)).to.equal(await seller.getAddress())
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

})
