import React, { useEffect, useState } from "react";
import { createRoot } from "react-dom/client";


function Public() {
const userId = window.location.pathname.split("/").pop();
const [data, setData] = useState([]);


useEffect(() => {
	fetch(`/api/public/${userId}`)
		.then(r => r.json())
		.then(setData);
}, []);


return (
<div style={{ padding: 20 }}>
<h1>Public Workouts</h1>
{data.map((w, i) => (
<div key={i}>{w.day}: {w.calories} kcal</div>
))}
</div>
);
}


createRoot(document.getElementById("root")).render(<Public />);