import React from 'react'
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom'
import Dashboard from './dashboard'
import PublicPage from './public'

function LoginPage() {
  return (
    <div style={{ padding: 20 }}>
      <h2>Login</h2>
      <p>Login handled by backend. Open the app and use OAuth/login flows.</p>
    </div>
  )
}

export default function App() {
  return (
    <Router>
      <Routes>
        <Route path="/auth/login" element={<LoginPage />} />
        <Route path="/dashboard" element={<Dashboard />} />
        <Route path="/public/:userId" element={<PublicPage />} />
        <Route path="/" element={<Navigate to="/dashboard" replace />} />
      </Routes>
    </Router>
  )
}
