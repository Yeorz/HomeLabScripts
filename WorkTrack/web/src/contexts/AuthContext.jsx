import React, { createContext, useContext, useState, useCallback, useEffect } from 'react';
import { secureApiCall, logSecurityEvent } from './security';

const AuthContext = createContext(null);

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  // Check session on app load
  useEffect(() => {
    const checkSession = async () => {
      try {
        const response = await fetch('http://localhost:3001/auth/session', {
          credentials: 'include',
        });
        
        if (response.ok) {
          const data = await response.json();
          setUser(data.user);
        }
      } catch (err) {
        logSecurityEvent('Session check failed', { error: err.message });
      } finally {
        setLoading(false);
      }
    };

    checkSession();
  }, []);

  const login = useCallback(async (email, password) => {
    setError(null);
    try {
      const data = await secureApiCall('http://localhost:3001/auth/login', {
        method: 'POST',
        body: JSON.stringify({ email, password }),
      });
      setUser(data.user);
      return data;
    } catch (err) {
      logSecurityEvent('Login failed', { email, error: err.message });
      setError(err.message);
      throw err;
    }
  }, []);

  const logout = useCallback(async () => {
    try {
      await secureApiCall('http://localhost:3001/auth/logout', {
        method: 'POST',
      });
      setUser(null);
    } catch (err) {
      logSecurityEvent('Logout failed', { error: err.message });
    }
  }, []);

  // OAuth flow
  const initiateOAuth = useCallback((provider) => {
    const state = Math.random().toString(36).substring(7);
    sessionStorage.setItem('oauth_state', state);
    
    const params = new URLSearchParams({
      client_id: process.env.REACT_APP_OAUTH_CLIENT_ID || 'your-client-id',
      redirect_uri: `${window.location.origin}/auth/callback`,
      response_type: 'code',
      scope: 'openid profile email',
      state,
      provider,
    });

    window.location.href = `http://localhost:3001/auth/oauth?${params.toString()}`;
  }, []);

  // SAML flow
  const initiateSAML = useCallback(() => {
    window.location.href = 'http://localhost:3001/auth/saml/login';
  }, []);

  const value = {
    user,
    loading,
    error,
    login,
    logout,
    isAuthenticated: !!user,
    initiateOAuth,
    initiateSAML,
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within AuthProvider');
  }
  return context;
};
