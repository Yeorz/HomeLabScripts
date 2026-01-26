import React, { useEffect, useRef } from "react";
import Chart from "chart.js/auto";


export default function Charts({ data, labels, title }) {
const canvasRef = useRef(null);


useEffect(() => {
if (!data || !labels) return;
const ctx = canvasRef.current.getContext('2d');
new Chart(ctx, {
type: 'line',
data: {
labels,
datasets: [{ label: title, data, borderColor: '#4CAF50', backgroundColor: 'rgba(76,175,80,0.2)' }]
},
options: { responsive: true, plugins: { legend: { display: true, position: 'top' } } }
});
}, [data, labels, title]);


return <canvas ref={canvasRef}></canvas>;
}