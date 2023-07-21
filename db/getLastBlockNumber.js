const executeQuery = require('./executeQuery');

const GET_LAST_BLOCK = `
  query GetLastBlock {
    block(limit: 1, order_by: {number: desc}) {
      number
    }
  }
`;

async function getLastBlockNumber() {
  const data = await executeQuery(GET_LAST_BLOCK);
  
  if (data && data.block && data.block.length > 0) {
    return data.block[0].number;
  } else {
    throw new Error('No block data received');
  }
}

module.exports = getLastBlockNumber;