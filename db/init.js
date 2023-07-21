require('dotenv').config()

const ethers = require("ethers");
const addBlocksToDB = require("./addBlocks");
const formatTimestampToISO = require("./formatTimestampToISO");
const getLastBlockNumber = require("./getLastBlockNumber")

async function getBlockData(provider, blockNumber) {

    const res = await provider.getBlock(blockNumber);

    return { base_fee: res.baseFeePerGas.toString(), number: blockNumber, timestamp: formatTimestampToISO(res.timestamp) };
}

async function getXBlockData(provider, blockNumberStart, blockNumberEnd) {
    const data = [];
    if (blockNumberEnd <= blockNumberStart) {
        return data;
    }

    // for (range(0, i))
    for (i of Array(blockNumberEnd + 1 - blockNumberStart).keys()) {
        data.push(await getBlockData(provider, i + blockNumberStart));
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

async function pushToDB(startingBlockNb) {
    const provider = new ethers.JsonRpcProvider(rpc);

    const steps = getBlockNbSteps(startingBlockNb ?? FIRST_BLOCK, LAST_BLOCK, STEPS_NB);

    for (let i = 0; i < steps.length - 1; ++i) {
        const data = await getXBlockData(provider, steps[i], steps[i + 1]);
        console.log(`pushing blocks ${steps[i]} to ${steps[i + 1]}...`);
        const res = await addBlocksToDB(data);
        console.log("🚀 ~ file: init.js:55 ~ pushToDB ~ res:", res)
    }
}

async function main() {
    const sleep = function sleep(seconds) {
        return new Promise(resolve => setTimeout(resolve, seconds * 1000));
    }

    let currentBlockNb = await getLastBlockNumber();

    while (currentBlockNb !== LAST_BLOCK) {
        try {
            currentBlockNb = await getLastBlockNumber();
            console.log(`current block: ${currentBlockNb ?? FIRST_BLOCK}`);
            await pushToDB(currentBlockNb);
        } catch (e) {
            console.log(e);
            await sleep(5);
            console.log(`\nretrying...`)
        }
    }
}

main()