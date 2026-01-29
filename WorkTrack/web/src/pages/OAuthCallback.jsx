import React, { useEffect, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import { logSecurityEvent } from '../utils/security';

export default function OAuthCallback() {
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();
  const { user } = useAuth();
  const [error, setError] = useState(null);

  useEffect(() => {
    const handleCallback = async () => {
      try {
        const code = searchParams.get('code');
        const state = searchParams.get('state');
        const storedState = sessionStorage.getItem('oauth_state');

        // Validate state parameter (CSRF protection)
        if (state !== storedState) {
          logSecurityEvent('OAuth state mismatch', { received: state, stored: storedState });
          throw new Error('Invalid state parameter - possible CSRF attack');
        }

        if (!code) {
          throw new Error('No authorization code received');
        }

        // Exchange code for token
        const response = await fetch('http://localhost:3001/auth/oauth/callback', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          credentials: 'include',
          body: JSON.stringify({ code, state }),
        });

        if (!response.ok) {
          throw new Error(`OAuth callback failed: ${response.statusText}`);
        }

        sessionStorage.removeItem('oauth_state');
        navigate('/dashboard');
      } catch (err) {
        logSecurityEvent('OAuth callback error', { error: err.message });
        setError(err.message);
        navigate('/auth/login');
      }
    };

    if (searchParams.get('code')) {
      handleCallback();
    }
  }, [searchParams, navigate]);

  if (error) {
    return <div>Error: {error}</div>;
  }

  return <div>Processing authentication...</div>;
}
