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

function fetchHasura(variables) {
  return fetch(HASURA_ENDPOINT, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-hasura-admin-secret": HASURA_SECRET,
    },
    body: JSON.stringify({
      query: ADD_BLOCKS,
      variables: variables,
    }),
  })
    .then((response) => {
      if (!response.ok) {
        throw new Error("HTTP error " + response.status);
      }
      return response.json();
    })
    .catch(function () {
      console.log("There was a network error.");
    });
}

module.exports = fetchHasura
