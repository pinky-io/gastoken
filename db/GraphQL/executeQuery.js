const axios = require('axios');

const HASURA_ENDPOINT = process.env.HASURA_ENDPOINT;
const HASURA_SECRET = process.env.HASURA_SECRET;

async function executeQuery(query, variables = {}) {
  try {
    const response = await axios({
      url: HASURA_ENDPOINT,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-hasura-admin-secret': HASURA_SECRET,
      },
      data: {
        query: query,
        variables: variables,
      },
    });

    if (response.data.errors) {
      throw new Error(response.data.errors[0].message);
    }

    return response.data.data;
  } catch (error) {
    console.error('There was an error executing the query: ', error);
    return null;
  }
}

module.exports = executeQuery;