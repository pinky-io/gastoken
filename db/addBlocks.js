const axios = require("axios");

const HASURA_ENDPOINT = process.env.HASURA_ENDPOINT;
const HASURA_SECRET = process.env.HASURA_SECRET;

// Utilisation de la fonction
const ADD_BLOCKS = `
    mutation AddBlocks($base_fee: bigint, $number: Int, $timestamp: timestamptz) {
        insert_block(objects: {base_fee: $base_fee, number: $number, timestamp: $timestamp}) {
            affected_rows
        }
    }
`;

function addBlocks(variables) {
  return axios({
    url: HASURA_ENDPOINT,
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-hasura-admin-secret": HASURA_SECRET,
    },
    data: {
      query: ADD_BLOCKS,
      variables: variables,
    },
  }).then((response) => {
    return response.data;
  });
}

module.exports = addBlocks;
