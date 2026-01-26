import React, { useEffect, useState } from "react";
import { createRoot } from "react-dom/client";
import Chart from "chart.js/auto";


function App() {
const [data, setData] = useState([]);


useEffect(() => {
fetch("http://localhost:3001/analytics", {
headers: { Authorization: "Bearer " + localStorage.token }
})
.then(r => r.json())
.then(d => {
setData(d);
new Chart(document.getElementById("c"), {
type: "line",
data: {
labels: d.map(x => x.day),
datasets: [{ data: d.map(x => x.calories) }]
}
});
});
}, []);


return <canvas id="c"></canvas>;
}


createRoot(document.getElementById("root")).render(<App />);