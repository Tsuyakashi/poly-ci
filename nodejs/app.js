const express = require('express');
const app = express();
const port = 80;

app.get('/', (req, res) => res.send('Hello World!'));

const quotes = [
    "Код работает? Не трогай.",
    "Семь раз отмерь, один раз запушь.",
    "В любой непонятной ситуации делай git status."
];

app.get('/quote', (req, res) => {
    const randomIndex = Math.floor(Math.random() * quotes.length);
    res.send(quotes[randomIndex]);
});

app.listen(port, () => console.log(`App listening at http://localhost:${port}`));
