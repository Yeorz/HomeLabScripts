import React, { useEffect, useState } from 'react';
import { View, Text, FlatList } from 'react-native';
import NetInfo from '@react-native-community/netinfo';
import BackgroundFetch from 'react-native-background-fetch';
import { saveWorkoutOffline, syncPendingWorkouts } from './storage';


export default function App() {
const token = 'YOUR_AUTH_TOKEN'; // Replace with real token storage
const [pendingCount, setPendingCount] = useState(0);


async function logWorkout(workout) {
try {
const res = await fetch("http://localhost:3001/workouts", {
method: "POST",
headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
body: JSON.stringify(workout)
});
if (!res.ok) await saveWorkoutOffline(workout);
} catch {
await saveWorkoutOffline(workout);
}
updatePendingCount();
}


async function updatePendingCount() {
const stored = JSON.parse(await AsyncStorage.getItem('pending_workouts')) || [];
setPendingCount(stored.length);
}


useEffect(() => {
// Initial sync on app start
syncPendingWorkouts(token).then(updatePendingCount);


// Listen for connectivity changes
const unsubscribe = NetInfo.addEventListener(state => {
if (state.isConnected) syncPendingWorkouts(token).then(updatePendingCount);
});


// Background fetch registration
BackgroundFetch.configure(
{ minimumFetchInterval: 15, stopOnTerminate: false, startOnBoot: true },
async taskId => {
await syncPendingWorkouts(token);
updatePendingCount();
BackgroundFetch.finish(taskId);
},
error => { console.log("Background fetch failed", error); }
);


return () => unsubscribe();
}, []);


// Example logging a workout
useEffect(() => {
logWorkout({ type: 'Strength', duration: 1800, calories: 220 });
}, []);


return (
<View style={{ padding: 20 }}>
<Text>Workout Tracker</Text>
{pendingCount > 0 && <Text style={{ color: 'red' }}>Pending uploads: {pendingCount}</Text>}
</View>
);
}