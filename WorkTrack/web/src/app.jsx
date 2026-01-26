import React from "react";
import { createRoot } from "react-dom/client";
import Dashboard from "./dashboard";
import Public from "./public";


const path = window.location.pathname;


if (path.startsWith('/public')) {
createRoot(document.getElementById('root')).render(<Public />);
} else {
createRoot(document.getElementById('root')).render(<Dashboard />);
}