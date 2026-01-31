import React, { useEffect, useRef } from "react";
import Chart from "chart.js/auto";


export default function Charts({ data, labels, title }) {
	const canvasRef = useRef(null);
	const chartRef = useRef(null);

	useEffect(() => {
		if (!data || !labels) return;
		const ctx = canvasRef.current.getContext('2d');

		// destroy previous instance if exists
		if (chartRef.current) {
			try { chartRef.current.destroy(); } catch (e) {}
			chartRef.current = null;
		}

		chartRef.current = new Chart(ctx, {
			type: 'line',
			data: {
				labels,
				datasets: [{ label: title, data, borderColor: '#4CAF50', backgroundColor: 'rgba(76,175,80,0.2)' }]
			},
			options: { responsive: true, plugins: { legend: { display: true, position: 'top' } } }
		});

		return () => {
			if (chartRef.current) {
				try { chartRef.current.destroy(); } catch (e) {}
				chartRef.current = null;
			}
		};
	}, [data, labels, title]);


	return <canvas ref={canvasRef}></canvas>;
}