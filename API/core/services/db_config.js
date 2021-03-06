const Pool = require('pg').Pool

//Keeps nodejs from formatting timestamps without timezones
var pg = require('pg');
var types = pg.types;
types.setTypeParser(1114, (stringValue) => {
return stringValue;
});

//For connecting to the DB
const DB_HOST = process.env.DB_HOST;
const DB_NAME = process.env.DB_NAME;
const DB_USERNAME = process.env.DB_USER;
const DB_PASSWORD = process.env.DB_PASSWORD;
const PRODUCTION = process.env.DEV_STATUS === 'production';

const pool = new Pool
({
    user:DB_USERNAME,
    host:DB_HOST,
    database:DB_NAME,
    password:DB_PASSWORD
});

const dbErrorHandler = (res,err) =>
{
    if(!PRODUCTION)
    {
        console.log("DB ERROR: " + err.message);
        res.status(500).json({"DB ERROR": err.message});
    }
    else
    {
        res.status(500).end();
    }
}

const dbErrorHandlerNoResponse = (err) =>
{
    if(!PRODUCTION)
    {
        console.log("DB ERROR: " + err.message);
    }
}

module.exports = {pool,dbErrorHandler,dbErrorHandlerNoResponse};
