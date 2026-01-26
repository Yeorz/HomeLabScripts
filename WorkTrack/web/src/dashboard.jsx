import React, { useEffect, useState } from "react";
import Charts from "./charts";


export default function Dashboard() {
const [summary, setSummary] = useState([]);
const [trends, setTrends] = useState([]);


useEffect(() => {
const token = localStorage.token;
fetch('http://localhost:3001/analytics/summary', { headers: { Authorization: `Bearer ${token}` } })
.then(r => r.json()).then(setSummary);
fetch('http://localhost:3001/analytics/trends', { headers: { Authorization: `Bearer ${token}` } })
.then(r => r.json()).then(setTrends);
}, []);


const labels = trends.map(t => t.day);
const calories = trends.map(t => t.calories);
const minutes = trends.map(t => t.minutes);


const publicLink = `${window.location.origin}/public/${localStorage.userId}`;


return (
<div style={{ padding: 20 }}>
<h1>My Dashboard</h1>
<div>
<h2>Public Link</h2>
<input type="text" readOnly value={publicLink} style={{ width: '80%' }} />
</div>
<div>
<h2>Trends</h2>
<Charts data={calories} labels={labels} title="Calories" />
<Charts data={minutes} labels={labels} title="Minutes" />
</div>
<div>
<h2>Summary</h2>
<ul>
{summary.map(s => (
<li key={s.type}>{s.type}: {s.sessions} sessions, {s.total_minutes} min, {s.calories} kcal</li>
))}
</ul>
</div>
</div>
);
}