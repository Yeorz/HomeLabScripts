import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import { sanitizeInput, validators, createRateLimiter, logSecurityEvent } from '../utils/security';
import { useForm } from 'react-hook-form';

const loginLimiter = createRateLimiter(5, 15 * 60 * 1000); // 5 attempts per 15 mins

export default function LoginPage() {
  const navigate = useNavigate();
  const { login, initiateOAuth, initiateSAML } = useAuth();
  const { register, handleSubmit, formState: { errors } } = useForm();
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState(null);

  const onSubmit = async (data) => {
    setError(null);
    
    // Rate limiting
    const rateLimitCheck = loginLimiter(data.email);
    if (!rateLimitCheck.allowed) {
      logSecurityEvent('Login rate limit exceeded', { email: data.email });
      setError(`Too many login attempts. Try again in ${rateLimitCheck.retryAfter} seconds.`);
      return;
    }

    setIsLoading(true);

    try {
      // Validate inputs
      const email = sanitizeInput(data.email);
      const password = data.password;

      if (!validators.email(email)) {
        throw new Error('Invalid email format');
      }

      if (!validators.password(password)) {
        throw new Error('Password must be at least 12 characters');
      }

      await login(email, password);
      navigate('/dashboard');
    } catch (err) {
      logSecurityEvent('Login error', { error: err.message });
      setError(err.message);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div style={styles.container}>
      <div style={styles.card}>
        <h1>Workout Tracker Login</h1>

        {error && <div style={styles.error}>{error}</div>}

        <form onSubmit={handleSubmit(onSubmit)} style={styles.form}>
          <div style={styles.formGroup}>
            <label>Email</label>
            <input
              type="email"
              {...register('email', { required: 'Email is required' })}
              style={styles.input}
              disabled={isLoading}
            />
            {errors.email && <span style={styles.fieldError}>{errors.email.message}</span>}
          </div>

          <div style={styles.formGroup}>
            <label>Password</label>
            <input
              type="password"
              {...register('password', { required: 'Password is required' })}
              style={styles.input}
              disabled={isLoading}
            />
            {errors.password && <span style={styles.fieldError}>{errors.password.message}</span>}
          </div>

          <button type="submit" style={styles.button} disabled={isLoading}>
            {isLoading ? 'Logging in...' : 'Login'}
          </button>
        </form>

        <div style={styles.divider}>Or continue with</div>

        <div style={styles.oauth}>
          <button
            type="button"
            onClick={() => initiateOAuth('google')}
            style={{ ...styles.oauthButton, backgroundColor: '#4285F4' }}
            disabled={isLoading}
          >
            Google
          </button>
          <button
            type="button"
            onClick={() => initiateOAuth('github')}
            style={{ ...styles.oauthButton, backgroundColor: '#333' }}
            disabled={isLoading}
          >
            GitHub
          </button>
        </div>

        <div style={styles.divider}>Enterprise</div>

        <button
          type="button"
          onClick={() => initiateSAML()}
          style={{ ...styles.button, backgroundColor: '#666' }}
          disabled={isLoading}
        >
          SAML Login
        </button>

        <p style={styles.footer}>
          Don't have an account? <a href="/auth/register">Register here</a>
        </p>
      </div>
    </div>
  );
}

const styles = {
  container: {
    display: 'flex',
    justifyContent: 'center',
    alignItems: 'center',
    minHeight: '100vh',
    backgroundColor: '#f5f6fa',
  },
  card: {
    backgroundColor: '#fff',
    padding: '40px',
    borderRadius: '12px',
    boxShadow: '0 2px 8px rgba(0,0,0,0.1)',
    width: '100%',
    maxWidth: '400px',
  },
  form: {
    marginBottom: '20px',
  },
  formGroup: {
    marginBottom: '16px',
  },
  input: {
    width: '100%',
    padding: '10px',
    border: '1px solid #ddd',
    borderRadius: '6px',
    fontSize: '14px',
    boxSizing: 'border-box',
  },
  button: {
    width: '100%',
    padding: '12px',
    backgroundColor: '#4CAF50',
    color: '#fff',
    border: 'none',
    borderRadius: '6px',
    fontSize: '16px',
    fontWeight: 'bold',
    cursor: 'pointer',
  },
  divider: {
    textAlign: 'center',
    margin: '20px 0',
    color: '#999',
    fontSize: '12px',
  },
  oauth: {
    display: 'grid',
    gridTemplateColumns: '1fr 1fr',
    gap: '10px',
    marginBottom: '20px',
  },
  oauthButton: {
    padding: '12px',
    color: '#fff',
    border: 'none',
    borderRadius: '6px',
    cursor: 'pointer',
    fontWeight: 'bold',
  },
  error: {
    backgroundColor: '#fee',
    color: '#c00',
    padding: '12px',
    borderRadius: '6px',
    marginBottom: '16px',
    fontSize: '14px',
  },
  fieldError: {
    color: '#c00',
    fontSize: '12px',
    marginTop: '4px',
    display: 'block',
  },
  footer: {
    textAlign: 'center',
    fontSize: '14px',
    marginTop: '20px',
  },
};
