import { Contract } from "ethers";
import hre, { ethers } from "hardhat";

async function main() {
  const [root] = await ethers.getSigners();
  const constructorArguments = ["0x4976A688f130248Fa4AFcf4903440547C63c3288"];
  const receiverAddress = root.address;
  const Greeter = await ethers.getContractFactory("PaymentGate");
  const greeter = await Greeter.deploy(constructorArguments[0]);

  console.log(greeter.deployTransaction.hash);

  await greeter.deployed();

  console.log("Greeter deployed to:", greeter.address);

  const contract = new Contract(greeter.address, Greeter.interface, root);
  const tx = await contract.setReceiverContract(receiverAddress);
  await tx.wait();
  console.log("Receiver contract set");

  await seep(5000);

  await hre.run("verify:verify", {
    address: greeter.address,
    constructorArguments,
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

async function seep(timeout: number) {
  return new Promise<void>((resolve, reject) => {
    setTimeout(() => {
      resolve();
    }, timeout);
  });
}
