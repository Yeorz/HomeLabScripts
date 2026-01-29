import React, { useEffect, useState } from 'react';
import { sanitizeInput } from '../utils/security';
import Charts from '../components/Charts';

export default function PublicPage() {
  const userId = window.location.pathname.split('/').pop();
  const [data, setData] = useState([]);
  const [userName, setUserName] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    const fetchPublicData = async () => {
      try {
        // Validate userId format (UUID or numeric)
        if (!userId || !/^[0-9a-f-]+$|^\d+$/i.test(userId)) {
          throw new Error('Invalid user ID format');
        }

        const response = await fetch(`http://localhost:3001/public/${encodeURIComponent(userId)}`);
        
        if (!response.ok) {
          throw new Error('User not found or sharing disabled');
        }

        const result = await response.json();
        setData(result.workouts || []);
        setUserName(result.userName || 'Anonymous');
      } catch (err) {
        setError(err.message);
      } finally {
        setLoading(false);
      }
    };

    if (userId) {
      fetchPublicData();
    }
  }, [userId]);

  if (loading) {
    return <div style={styles.container}>Loading...</div>;
  }

  if (error) {
    return <div style={styles.container}><div style={styles.error}>Error: {error}</div></div>;
  }

  const labels = data.map(w => sanitizeInput(String(w.day)));
  const calories = data.map(w => Math.max(0, parseInt(w.calories) || 0));

  return (
    <div style={styles.container}>
      <header style={styles.header}>
        <h1>{sanitizeInput(userName)}'s Workout Progress</h1>
        <p>Public workout statistics</p>
      </header>

      {data.length === 0 ? (
        <div style={styles.card}>
          <p>No workouts recorded yet.</p>
        </div>
      ) : (
        <>
          <div style={styles.card}>
            <h2>Calories Burned</h2>
            <Charts data={calories} labels={labels} title="Calories" />
          </div>

          <div style={styles.card}>
            <h2>Workout History</h2>
            <div style={styles.workoutList}>
              {data.map((w, i) => (
                <div key={i} style={styles.workoutItem}>
                  <span style={styles.date}>{sanitizeInput(String(w.day))}</span>
                  <span style={styles.calories}>{Math.max(0, parseInt(w.calories) || 0)} kcal</span>
                </div>
              ))}
            </div>
          </div>
        </>
      )}
    </div>
  );
}

const styles = {
  container: {
    minHeight: '100vh',
    backgroundColor: '#f5f6fa',
    padding: '20px',
    fontFamily: 'Arial, sans-serif',
  },
  header: {
    backgroundColor: '#fff',
    padding: '30px',
    borderRadius: '12px',
    boxShadow: '0 2px 6px rgba(0,0,0,0.1)',
    marginBottom: '30px',
    textAlign: 'center',
  },
  card: {
    backgroundColor: '#fff',
    padding: '30px',
    borderRadius: '12px',
    boxShadow: '0 2px 6px rgba(0,0,0,0.1)',
    marginBottom: '30px',
  },
  error: {
    backgroundColor: '#fee',
    color: '#c00',
    padding: '15px',
    borderRadius: '6px',
  },
  workoutList: {
    display: 'flex',
    flexDirection: 'column',
    gap: '10px',
  },
  workoutItem: {
    display: 'flex',
    justifyContent: 'space-between',
    padding: '12px',
    backgroundColor: '#f9f9f9',
    borderRadius: '6px',
    borderLeft: '4px solid #4CAF50',
  },
  date: {
    fontWeight: 'bold',
    color: '#333',
  },
  calories: {
    color: '#FF6B6B',
    fontWeight: 'bold',
  },
};
