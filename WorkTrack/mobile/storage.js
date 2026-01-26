import AsyncStorage from '@react-native-async-storage/async-storage';
import NetInfo from '@react-native-community/netinfo';


const WORKOUT_KEY = 'pending_workouts';


export async function saveWorkoutOffline(workout) {
const existing = JSON.parse(await AsyncStorage.getItem(WORKOUT_KEY)) || [];
existing.push(workout);
await AsyncStorage.setItem(WORKOUT_KEY, JSON.stringify(existing));
}


export async function syncPendingWorkouts(token) {
const existing = JSON.parse(await AsyncStorage.getItem(WORKOUT_KEY)) || [];
if (existing.length === 0) return;


const state = await NetInfo.fetch();
if (!state.isConnected) return;


const remaining = [];
for (let workout of existing) {
try {
const res = await fetch("http://localhost:3001/workouts", {
method: "POST",
headers: {
'Content-Type': 'application/json',
Authorization: `Bearer ${token}`
},
body: JSON.stringify(workout)
});
if (!res.ok) remaining.push(workout);
} catch {
remaining.push(workout);
}
}
await AsyncStorage.setItem(WORKOUT_KEY, JSON.stringify(remaining));
}