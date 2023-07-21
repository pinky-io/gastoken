const axios = require("axios");
const executeQuery = require("./executeQuery");

const HASURA_ENDPOINT = process.env.HASURA_ENDPOINT;
const HASURA_SECRET = process.env.HASURA_SECRET;

const ADD_BLOCKS = `
    mutation AddBlocks($objects: [block_insert_input!]!) {
      insert_block(objects: $objects, on_conflict: {constraint: block_pkey, update_columns: []}) {
        affected_rows
      }
    }
`;

async function addBlocks(objects) {
  const response = await executeQuery(ADD_BLOCKS, { objects });

  return response;
}

module.exports = addBlocks;
