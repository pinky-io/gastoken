const ethers = require("ethers");

async function getBlockData(provider, blockNumber) {

    const res = await provider.getBlock(blockNumber);

    return res.baseFeePerGas;
}

async function getXBlockData(provider, blockNumberStart, blockNumberEnd) {
    if (blockNumberEnd <= blockNumberStart) {
        return;
    }

    const data = [];

    for (i of Array(blockNumberEnd - blockNumberStart).keys()) {
        data.push(getBlockData(provider, i + blockNumberStart));
    }

    return data;
}


const provider = new ethers.JsonRpcProvider("https://eth-sepolia.public.blastapi.io");
provider.getBlockNumber().then(blockNumber => getBlockData(provider, blockNumber)).then(console.log);

