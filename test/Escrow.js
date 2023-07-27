const { expect } = require('chai')
const { ethers } = require('hardhat')

const tokens = (number) => {
  return ethers.parseUnits(number.toString(), 'ether')
}

describe('Escrow', () => {

})