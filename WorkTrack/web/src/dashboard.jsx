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
<div style={{ padding: 30, fontFamily: 'Arial, sans-serif', backgroundColor: '#f5f6fa', minHeight: '100vh' }}>
<h1 style={{ marginBottom: 20 }}>My Workout Dashboard</h1>


{/* Public Link Card */}
<div style={{ marginBottom: 30, padding: 20, borderRadius: 12, backgroundColor: '#fff', boxShadow: '0 2px 6px rgba(0,0,0,0.15)' }}>
<h2>Public Link</h2>
<input type="text" readOnly value={publicLink} style={{ width: '70%', marginRight: 10, padding: 8, borderRadius: 6, border: '1px solid #ccc' }} />
<button onClick={() => navigator.clipboard.writeText(publicLink)} style={{ padding: '8px 12px', borderRadius: 6, backgroundColor: '#4CAF50', color: '#fff', border: 'none', cursor: 'pointer' }}>Copy</button>
</div>


{/* Trends Charts */}
<div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 30, marginBottom: 30 }}>
<div style={{ padding: 20, borderRadius: 12, backgroundColor: '#fff', boxShadow: '0 2px 6px rgba(0,0,0,0.15)' }}>
<h3>Calories Trend</h3>
<Charts data={calories} labels={labels} title="Calories" />
</div>
<div style={{ padding: 20, borderRadius: 12, backgroundColor: '#fff', boxShadow: '0 2px 6px rgba(0,0,0,0.15)' }}>
<h3>Minutes Trend</h3>
<Charts data={minutes} labels={labels} title="Minutes" />
</div>
</div>


{/* Summary Cards */}
<div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: 20 }}>
{summary.map(s => (
<div key={s.type} style={{ padding: 20, borderRadius: 12, backgroundColor: '#fff', boxShadow: '0 2px 6px rgba(0,0,0,0.15)' }}>
<h4>{s.type}</h4>
<p>Sessions: {s.sessions}</p>
<p>Total Minutes: {s.total_minutes}</p>
<p>Calories: {s.calories}</p>
</div>
))}
</div>
</div>
);
}