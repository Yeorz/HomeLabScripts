import * as SecureStore from "expo-secure-store";


async function syncWorkout(w) {
const token = await SecureStore.getItemAsync("token");
await fetch("http://localhost:3001/workouts", {
method: "POST",
headers: {
"Content-Type": "application/json",
Authorization: `Bearer ${token}`
},
body: JSON.stringify(w)
});
}


export default function App() {
syncWorkout({ type: "Strength", duration: 1800, calories: 220 });
return null;
}