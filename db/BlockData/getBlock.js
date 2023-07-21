const utils = require("./utils");

async function getBlockData(provider, blockNumber) {

    const res = await provider.getBlock(blockNumber);

    return { base_fee: res.baseFeePerGas.toString(), number: blockNumber, timestamp: utils.formatTimestampToISO(res.timestamp) };
}

async function getBlockDataRange(provider, blockNumberStart, blockNumberEnd) {
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

module.exports = {
    getBlockData,
    getBlockDataRange
}