async function main() {
  // get the signer
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", await deployer.getAddress());
  // deploy the property NFT contract
  property = await ethers.deployContract("Property", [])
  await property.waitForDeployment()
  console.log(`Property contract successfully deployed to ${await property.getAddress()}`)
  // deployer is the legalentity
  escrow = await ethers.deployContract("Escrow", [property.getAddress(),
    '0xF45afaB6a593A6d1E2B67A8Ca59AD95aA0412ffE', // appraiser
    '0x2029228CcA65603185Da435B368f2B6069CD16B4', // inspector
    '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266']) // lender
  await escrow.waitForDeployment()
  console.log(`Escrow contract successfully deployed to ${await escrow.getAddress()}`)

  bidding = await ethers.deployContract("Bidding", [property.getAddress(), escrow.getAddress()])
  await bidding.waitForDeployment()
  console.log(`Bidding contract successfully deployed to ${await bidding.getAddress()}`)


  // Now, set the Bidding contract's address in the Escrow contract
  await escrow.setBiddingContract(bidding.getAddress())
  console.log("Sucessfully set the Bidding contract to the state")
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });