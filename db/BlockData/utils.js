function formatTimestampToISO(timestamp) {
  const date = new Date(timestamp * 1000);

  return date.toISOString();
}

function sleep(seconds) {
  return new Promise(resolve => setTimeout(resolve, seconds * 1000));
}


module.exports = {
  formatTimestampToISO,
  sleep
}
