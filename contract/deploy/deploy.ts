const { deployContract, getWallet } = require("./utils");

async function main() {
  const wallet = getWallet();

  await deployContract("Bluum", [], {
    wallet,
    verify: true,
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Deployment error:", error);
    process.exit(1);
  });
