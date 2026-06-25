const express = require('express');
const morgan = require('morgan')
const app = express();
const port = process.env.PORT || 8080;

app.use(morgan('short', {
    skip: (req, res) => req.url === '/health' || req.url === '/healthcheck'
}));

const quotes = [
    "Код работает? Не трогай.",
    "Семь раз отмерь, один раз запушь.",
    "В любой непонятной ситуации делай git status."
];

app.get('/', (req, res) => {
    res.send('Hello World!');
});

app.get('/quote', (req, res) => {
    const randomIndex = Math.floor(Math.random() * quotes.length);
    res.send(quotes[randomIndex]);
});

app.get('/health', (req, res) => {
    res.json({ status: "ok" });
});

app.listen(port, () => {
    console.log(`[${new Date().toISOString()}] INFO: Server started on port ${port}`);
});
