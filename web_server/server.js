const express = require("express");
const app = express();
const server = require("https").createServer(app);

app.use(function(req, res, next) {
    res.setHeader("Cross-Origin-Opener-Policy", "same-origin");
    res.setHeader("Cross-Origin-Embedder-Policy", "require-corp");
    next();
});

app.use(express.static("public"));

server.listen(6766, function() {
    console.log("listening on port: ", 6766);
});