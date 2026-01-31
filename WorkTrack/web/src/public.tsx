import React, { useEffect, useState } from 'react'

export default function PublicPage(): JSX.Element {
  const userId = window.location.pathname.split('/').pop() || ''
  const [data, setData] = useState<any[]>([])

  useEffect(() => {
    fetch(`/api/public/${userId}`)
      .then(r => r.json())
      .then(setData)
      .catch(() => setData([]))
  }, [userId])

  return (
    <div style={{ padding: 20 }}>
      <h1>Public Workouts</h1>
      {data.map((w, i) => (
        <div key={i}>{w.day}: {w.calories} kcal</div>
      ))}
    </div>
  )
}
