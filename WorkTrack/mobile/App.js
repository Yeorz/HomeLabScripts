import React, { useEffect, useState } from 'react';
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
await loadPendingWorkouts();
loadWorkoutsHistory(workout);
}


async function loadPendingWorkouts() {
const stored = JSON.parse(await AsyncStorage.getItem('pending_workouts')) || [];
setPendingCount(stored.length);
}


function loadWorkoutsHistory(workout) {
setWorkouts(prev => [{ ...workout, id: prev.length + 1, pending: true }, ...prev]);
}


useEffect(() => {
// Initial sync
syncPendingWorkouts(token).then(loadPendingWorkouts);


const unsubscribe = NetInfo.addEventListener(state => {
if (state.isConnected) syncPendingWorkouts(token).then(loadPendingWorkouts);
});


BackgroundFetch.configure(
{ minimumFetchInterval: 15, stopOnTerminate: false, startOnBoot: true },
async taskId => {
await syncPendingWorkouts(token);
await loadPendingWorkouts();
BackgroundFetch.finish(taskId);
},
error => console.log('Background fetch failed', error)
);


return () => unsubscribe();
}, []);


return (
<View style={styles.container}>
<Text style={styles.header}>Workout Tracker</Text>
{pendingCount > 0 && <Text style={styles.pending}>Pending uploads: {pendingCount}</Text>}
<Button title="Log Strength Workout" onPress={() => logWorkout({ type: 'Strength', duration: 1800, calories: 220 })} />


<Text style={styles.historyHeader}>Workout History</Text>
<FlatList
data={workouts}
keyExtractor={item => item.id.toString()}
renderItem={({ item }) => (
<View style={[styles.card, item.pending && styles.pendingCard]}>
<Text style={styles.type}>{item.type}</Text>
<Text>{item.duration} sec, {item.calories} kcal</Text>
{item.pending && <Text style={styles.pendingText}>Pending Upload</Text>}
</View>
)}
/>
</View>
);
}


const styles = StyleSheet.create({
container: { flex: 1, padding: 20, backgroundColor: '#f5f6fa' },
header: { fontSize: 24, fontWeight: 'bold', marginBottom: 10 },
pending: { color: 'red', marginBottom: 10 },
historyHeader: { fontSize: 20, marginTop: 20, marginBottom: 10 },
card: { padding: 12, marginBottom: 6, borderRadius: 10, backgroundColor: '#fff', elevation: 2 },
pendingCard: { borderColor: 'red', borderWidth: 1 },
type: { fontWeight: 'bold' },
pendingText: { color: 'red' }
});