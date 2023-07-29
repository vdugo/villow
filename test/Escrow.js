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
    it('sets the deployer as the legalEntity in the state', async () => {
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

})
