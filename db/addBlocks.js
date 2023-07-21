const axios = require("axios");

const HASURA_ENDPOINT = process.env.HASURA_ENDPOINT;
const HASURA_SECRET = process.env.HASURA_SECRET;

const ADD_BLOCKS = `
    mutation AddBlocks($objects: [block_insert_input!]!) {
        insert_block(objects: $objects) {
            affected_rows
        }
    }
`;

function addBlocks(objects) {
  return axios({
    url: HASURA_ENDPOINT,
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-hasura-admin-secret": HASURA_SECRET,
    },
    data: {
      query: ADD_BLOCKS,
      variables: { objects },
    },
  }).then((response) => {
    return response.data;
  });
}

module.exports = addBlocks;
