import React, { useEffect, useRef } from 'react';
import Chart from 'chart.js/auto';

export default function Charts({ data, labels, title }) {
  const canvasRef = useRef(null);
  const chartRef = useRef(null);

  useEffect(() => {
    if (!data || !labels || !canvasRef.current) return;

    // Destroy previous chart instance
    if (chartRef.current) {
      chartRef.current.destroy();
    }

    const ctx = canvasRef.current.getContext('2d');
    
    // Input validation
    const validData = data.filter(d => typeof d === 'number' && isFinite(d)).slice(0, 90);
    const validLabels = labels.slice(0, 90).map(l => String(l).substring(0, 50));

    if (validData.length === 0) {
      return;
    }

    chartRef.current = new Chart(ctx, {
      type: 'line',
      data: {
        labels: validLabels,
        datasets: [
          {
            label: title,
            data: validData,
            borderColor: '#4CAF50',
            backgroundColor: 'rgba(76,175,80,0.2)',
            tension: 0.4,
            fill: true,
            borderWidth: 2,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: true,
        plugins: {
          legend: {
            display: true,
            position: 'top',
          },
        },
        scales: {
          y: {
            beginAtZero: true,
            min: 0,
          },
        },
      },
    });

    return () => {
      if (chartRef.current) {
        chartRef.current.destroy();
      }
    };
  }, [data, labels, title]);

  return <canvas ref={canvasRef} />;
}
