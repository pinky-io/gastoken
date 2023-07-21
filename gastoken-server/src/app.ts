import express, { Request, Response } from 'express';
import cron from 'node-cron';
import populateDb from './jobs/populate-db.job';

const app = express();
const port = 3000;

cron.schedule('*/2 * * * *', populateDb);

app.listen(port, () => {
  console.log(`Server is running on http://localhost:${port}`);
});
