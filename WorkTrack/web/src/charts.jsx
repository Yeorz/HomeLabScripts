import React, { useEffect, useRef } from "react";
import Chart from "chart.js/auto";


export default function Charts({ data, labels, title }) {
const canvasRef = useRef(null);


useEffect(() => {
if (!data || !labels) return;
const ctx = canvasRef.current.getContext('2d');
new Chart(ctx, {
type: 'line',
data: { labels, datasets: [{ label: title, data }] },
options: { responsive: true }
});
}, [data, labels]);


return <canvas ref={canvasRef}></canvas>;
}