import React, { useEffect, useState } from 'react'
import { secureApiCall, sanitizeInput } from './utils/security'
import Charts from './charts'

export default function Dashboard(): JSX.Element {
  const [summary, setSummary] = useState<any[]>([])
  const [trends, setTrends] = useState<any[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    const fetchData = async () => {
      try {
        const summaryData = await secureApiCall('/api/analytics/summary', { method: 'GET' })
        const trendsData = await secureApiCall('/api/analytics/trends', { method: 'GET' })
        setSummary(summaryData)
        setTrends(trendsData)
      } catch (err: any) {
        setError(err.message)
      } finally {
        setLoading(false)
      }
    }
    fetchData()
  }, [])

  if (loading) return <div style={{ padding: 20 }}>Loading...</div>

  const labels = trends.map(t => sanitizeInput(String(t.day)))
  const calories = trends.map(t => Math.max(0, parseInt(t.calories) || 0))
  const minutes = trends.map(t => Math.max(0, parseInt(t.minutes) || 0))

  const publicLink = `${window.location.origin}/public/${summary[0]?.user_id || ''}`

  return (
    <div style={{ padding: 20 }}>
      <h1>My Workout Dashboard</h1>
      {error && <div style={{ color: 'red' }}>Error: {error}</div>}

      <div style={{ marginTop: 20 }}>
        <h2>Share Your Progress</h2>
        <input readOnly value={publicLink} style={{ width: '70%' }} />
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 20, marginTop: 20 }}>
        <div style={{ background: '#fff', padding: 20 }}>
          <h3>Calories Trend</h3>
          <Charts data={calories} labels={labels} title="Calories" />
        </div>
        <div style={{ background: '#fff', padding: 20 }}>
          <h3>Minutes Trend</h3>
          <Charts data={minutes} labels={labels} title="Minutes" />
        </div>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: 20, marginTop: 20 }}>
        {summary.map(s => (
          <div key={String(s.type)} style={{ background: '#fff', padding: 20 }}>
            <h4>{sanitizeInput(String(s.type))}</h4>
            <p>Sessions: {Math.max(0, parseInt(s.sessions) || 0)}</p>
            <p>Total Minutes: {Math.max(0, parseInt(s.total_minutes) || 0)}</p>
            <p>Calories: {Math.max(0, parseInt(s.calories) || 0)}</p>
          </div>
        ))}
      </div>
    </div>
  )
}
