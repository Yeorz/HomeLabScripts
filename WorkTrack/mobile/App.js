import { useEffect } from 'react';
import { saveWorkoutOffline, syncPendingWorkouts } from './storage';
import NetInfo from '@react-native-community/netinfo';


export default function App() {
// Replace with actual token storage logic
const token = 'YOUR_AUTH_TOKEN';


const workout = { type: 'Strength', duration: 1800, calories: 220 };


async function logWorkout() {
try {
await fetch("http://localhost:3001/workouts", {
method: "POST",
headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
body: JSON.stringify(workout)
});
} catch {
await saveWorkoutOffline(workout);
}
}


useEffect(() => {
// Listen for connectivity changes
const unsubscribe = NetInfo.addEventListener(state => {
if (state.isConnected) syncPendingWorkouts(token);
});


// Initial sync on app start
syncPendingWorkouts(token);


return () => unsubscribe();
}, []);


// Example usage: log a workout immediately
useEffect(() => {
logWorkout();
}, []);


return null; // UI placeholder
}