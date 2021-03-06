const express = require('express');
const express = require('express-favicon');
const path = require('path');
const port = process.env.PORT || 3000;
const app = express();
const http = require("http");

const server = http.createServer(app);

app.use(favicon(__dirname+'/build/favicon.ico'));
app.use(express.static(__dirname));
app.use(express.static(path.join(__dirname, 'build')));

app.get('/*', function(req, res){
    res.sendFile(path.join(__dirname, 'build', 'index.html'));
});

//app.listen(port);
server.listen(port);