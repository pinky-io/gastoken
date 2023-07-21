require('dotenv').config()

const ethers = require("ethers");
const addBlocksToDB = require("./GraphQL/addBlocks");
const getLastBlockNumber = require("./GraphQL/getLastBlockNumber");
const blockDataFunctions = require("./BlockData/getBlock");
const utils = require("./BlockData/utils");

const FIRST_BLOCK = 3887484;
const LAST_BLOCK = 3937884;
const STEPS_NB = 50;
const rpc = "https://eth-sepolia.public.blastapi.io";

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

async function pushToDB(startingBlockNb) {
    const provider = new ethers.JsonRpcProvider(rpc);

    const steps = getBlockNbSteps(startingBlockNb ?? FIRST_BLOCK, LAST_BLOCK, STEPS_NB);

    for (let i = 0; i < steps.length - 1; ++i) {
        const data = await blockDataFunctions.getBlockDataRange(provider, steps[i], steps[i + 1]);
        console.log(`pushing blocks ${steps[i]} to ${steps[i + 1]}...`);
        const res = await addBlocksToDB(data);
        console.log("🚀 ~ file: init.js:36 ~ pushToDB ~ res:", res)
    }
}

async function main() {
    let currentBlockNb = await getLastBlockNumber();

    while (currentBlockNb !== LAST_BLOCK) {
        try {
            currentBlockNb = await getLastBlockNumber();
            console.log(`current block: ${currentBlockNb ?? FIRST_BLOCK}`);
            await pushToDB(currentBlockNb);
        } catch (e) {
            console.log(e);
            await utils.sleep(5);
            console.log(`\nretrying...`)
        }
    }
}

main()