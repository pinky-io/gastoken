require('dotenv').config()

const ethers = require("ethers");
const addBlocksToDB = require("./addBlocks");

async function getBlockData(provider, blockNumber) {

    const res = await provider.getBlock(blockNumber);

    return { base_fee: res.baseFeePerGas, number: blockNumber, timestamp: res.timestamp };
}

async function getXBlockData(provider, blockNumberStart, blockNumberEnd) {
    const data = [];
    if (blockNumberEnd <= blockNumberStart) {
        return data;
    }

    // for (range(0, i))
    for (i of Array(blockNumberEnd - blockNumberStart).keys()) {
        data.push(getBlockData(provider, i + blockNumberStart));
        console.log(data[data.length - 1])

    }

    return data;
}

// Used to decomposed data call by chunk of `steps` elem
function getBlockNbSteps(firstBlockNb, lastBlockNb, steps) {
    const blockNumberSteps = [];
    let iterator = firstBlockNb;
    while (iterator < lastBlockNb) {
        blockNumberSteps.push(iterator);
        iterator = Math.min(iterator + steps, lastBlockNb);
    }
    blockNumberSteps.push(lastBlockNb);

    return blockNumberSteps;
}

const FIRST_BLOCK = 3930684;
const LAST_BLOCK = 3937884;
const STEPS_NB = 50;
const rpc = "https://eth-sepolia.public.blastapi.io";

async function pushToDB() {
    const provider = new ethers.JsonRpcProvider(rpc);
    const blockNb = await provider.getBlockNumber();

    // const steps = getBlockNbSteps(FIRST_BLOCK, LAST_BLOCK, STEPS_NB);
    const steps = [FIRST_BLOCK, FIRST_BLOCK + 2]

    for (i = 0; i < 1/*steps.length - 1*/; ++i) {
        const data = await getXBlockData(provider, steps[i], steps[i + 1]);
        console.log(`pushing blocks ${steps[i]} to ${steps[i + 1]}...`)
        addBlocksToDB(data);
    }
}

pushToDB()


//provider.getBlockNumber().then(blockNumber => getBlockData(provider, blockNumber)).then(console.log);

