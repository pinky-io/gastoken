"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const node_cron_1 = __importDefault(require("node-cron"));
const populate_db_job_1 = __importDefault(require("./jobs/populate-db.job"));
const app = (0, express_1.default)();
const port = 3000;
node_cron_1.default.schedule('*/2 * * * *', populate_db_job_1.default);
app.listen(port, () => {
    console.log(`Server is running on http://localhost:${port}`);
});
