import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from './contexts/AuthContext';
import { secureApiCall, sanitizeInput } from './utils/security';
import Charts from './components/Charts';

export default function Dashboard() {
  const navigate = useNavigate();
  const { user, logout, isAuthenticated } = useAuth();
  const [summary, setSummary] = useState([]);
  const [trends, setTrends] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    if (!isAuthenticated) {
      navigate('/auth/login');
      return;
    }

    const fetchData = async () => {
      try {
        const summaryData = await secureApiCall('http://localhost:3001/analytics/summary', {
          method: 'GET',
        });
        const trendsData = await secureApiCall('http://localhost:3001/analytics/trends', {
          method: 'GET',
        });

        setSummary(summaryData);
        setTrends(trendsData);
      } catch (err) {
        setError(err.message);
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, [isAuthenticated, navigate]);

  const handleLogout = async () => {
    await logout();
    navigate('/auth/login');
  };

  if (loading) {
    return <div style={styles.container}>Loading...</div>;
  }

  const labels = trends.map(t => sanitizeInput(String(t.day)));
  const calories = trends.map(t => Math.max(0, parseInt(t.calories) || 0));
  const minutes = trends.map(t => Math.max(0, parseInt(t.minutes) || 0));

  const publicLink = `${window.location.origin}/public/${user?.id || ''}`;

  return (
    <div style={styles.container}>
      <header style={styles.header}>
        <h1>My Workout Dashboard</h1>
        <div>
          <span style={styles.userName}>{user?.email}</span>
          <button onClick={handleLogout} style={styles.logoutBtn}>Logout</button>
        </div>
      </header>

      {error && <div style={styles.error}>Error: {error}</div>}

      {/* Public Link Card */}
      <div style={styles.card}>
        <h2>Share Your Progress</h2>
        <p>Generate a public link to share your workout stats:</p>
        <div style={styles.publicLinkContainer}>
          <input 
            type="text" 
            readOnly 
            value={publicLink} 
            style={styles.publicLinkInput}
            aria-label="Public profile link"
          />
          <button 
            onClick={() => navigator.clipboard.writeText(publicLink)}
            style={styles.copyBtn}
          >
            Copy
          </button>
        </div>
      </div>

      {/* Trends Charts */}
      <div style={styles.chartsGrid}>
        <div style={styles.card}>
          <h3>Calories Trend</h3>
          <Charts data={calories} labels={labels} title="Calories" />
        </div>
        <div style={styles.card}>
          <h3>Minutes Trend</h3>
          <Charts data={minutes} labels={labels} title="Minutes" />
        </div>
      </div>

      {/* Summary Cards */}
      <div style={styles.summaryGrid}>
        {summary.map(s => (
          <div key={sanitizeInput(String(s.type))} style={styles.summaryCard}>
            <h4>{sanitizeInput(String(s.type))}</h4>
            <p>Sessions: {Math.max(0, parseInt(s.sessions) || 0)}</p>
            <p>Total Minutes: {Math.max(0, parseInt(s.total_minutes) || 0)}</p>
            <p>Calories: {Math.max(0, parseInt(s.calories) || 0)}</p>
          </div>
        ))}
      </div>
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
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: '30px',
    backgroundColor: '#fff',
    padding: '20px',
    borderRadius: '12px',
    boxShadow: '0 2px 6px rgba(0,0,0,0.1)',
  },
  userName: {
    marginRight: '15px',
    color: '#666',
  },
  logoutBtn: {
    padding: '8px 16px',
    backgroundColor: '#f44336',
    color: '#fff',
    border: 'none',
    borderRadius: '6px',
    cursor: 'pointer',
  },
  card: {
    backgroundColor: '#fff',
    padding: '20px',
    borderRadius: '12px',
    boxShadow: '0 2px 6px rgba(0,0,0,0.1)',
    marginBottom: '30px',
  },
  publicLinkContainer: {
    display: 'flex',
    gap: '10px',
    marginTop: '10px',
  },
  publicLinkInput: {
    flex: 1,
    padding: '10px',
    border: '1px solid #ddd',
    borderRadius: '6px',
    fontSize: '14px',
  },
  copyBtn: {
    padding: '10px 20px',
    backgroundColor: '#4CAF50',
    color: '#fff',
    border: 'none',
    borderRadius: '6px',
    cursor: 'pointer',
  },
  chartsGrid: {
    display: 'grid',
    gridTemplateColumns: '1fr 1fr',
    gap: '20px',
    marginBottom: '30px',
  },
  summaryGrid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
    gap: '20px',
  },
  summaryCard: {
    backgroundColor: '#fff',
    padding: '20px',
    borderRadius: '12px',
    boxShadow: '0 2px 6px rgba(0,0,0,0.1)',
  },
  error: {
    backgroundColor: '#fee',
    color: '#c00',
    padding: '15px',
    borderRadius: '6px',
    marginBottom: '20px',
  },
};