import express from "express";
import sqlite3 from "sqlite3";
import cors from "cors";
import bcrypt from "bcrypt";
import jwt from "jsonwebtoken";
import { auth } from "./auth.js";


const app = express();
app.use(cors());
app.use(express.json());


const db = new sqlite3.Database("db.sqlite");


db.exec(`
CREATE TABLE IF NOT EXISTS users (
id INTEGER PRIMARY KEY,
email TEXT UNIQUE,
password TEXT
);


CREATE TABLE IF NOT EXISTS workouts (
id INTEGER PRIMARY KEY,
user_id INTEGER,
type TEXT,
duration INTEGER,
calories INTEGER,
created_at TEXT
);
`);


app.post("/register", async (req, res) => {
const hash = await bcrypt.hash(req.body.password, 10);
db.run("INSERT INTO users(email,password) VALUES (?,?)",
[req.body.email, hash], () => res.json({ ok: true })
);
});


app.post("/login", (req, res) => {
db.get("SELECT * FROM users WHERE email=?", [req.body.email], async (_, user) => {
if (!user || !(await bcrypt.compare(req.body.password, user.password))) return res.sendStatus(403);
res.json({ token: jwt.sign({ id: user.id }, "secret") });
});
});


app.post("/workouts", auth, (req, res) => {
const { type, duration, calories } = req.body;
db.run(
"INSERT INTO workouts(user_id,type,duration,calories,created_at) VALUES (?,?,?,?,datetime('now'))",
[req.user.id, type, duration, calories],
() => res.json({ ok: true })
);
});


// ADVANCED ANALYTICS
app.get("/analytics/summary", auth, (req, res) => {
db.all(
`SELECT
type,
app.listen(3001, () => console.log("Backend running"));
---(3001, () => console.log("Backend running"));