import React from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider } from './contexts/AuthContext';
import LoginPage from './pages/LoginPage';
import OAuthCallback from './pages/OAuthCallback';
import SAMLCallback from './pages/SAMLCallback';
import Dashboard from './dashboard';
import PublicPage from './pages/PublicPage';

function App() {
  return (
    <AuthProvider>
      <Router>
        <Routes>
          <Route path="/auth/login" element={<LoginPage />} />
          <Route path="/auth/callback" element={<OAuthCallback />} />
          <Route path="/auth/saml/callback" element={<SAMLCallback />} />
          <Route path="/dashboard" element={<Dashboard />} />
          <Route path="/public/:userId" element={<PublicPage />} />
          <Route path="/" element={<Navigate to="/dashboard" replace />} />
        </Routes>
      </Router>
    </AuthProvider>
  );
}

export default App;