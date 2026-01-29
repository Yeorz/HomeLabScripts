// Security utilities for XSS, CSRF, and input validation

import DOMPurify from 'dompurify';

// XSS Protection: Sanitize user input
export const sanitizeInput = (input) => {
  if (typeof input !== 'string') return input;
  return DOMPurify.sanitize(input, { 
    ALLOWED_TAGS: [], 
    ALLOWED_ATTR: [] 
  });
};

// Sanitize HTML output
export const sanitizeHTML = (html) => {
  return DOMPurify.sanitize(html, {
    ALLOWED_TAGS: ['b', 'i', 'em', 'strong', 'a', 'p', 'br', 'span'],
    ALLOWED_ATTR: ['href', 'target', 'rel']
  });
};

// CSRF Protection: Generate and validate tokens
export const generateCSRFToken = () => {
  const array = new Uint8Array(32);
  crypto.getRandomValues(array);
  return Array.from(array, byte => byte.toString(16).padStart(2, '0')).join('');
};

export const getCSRFToken = () => {
  let token = sessionStorage.getItem('csrf_token');
  if (!token) {
    token = generateCSRFToken();
    sessionStorage.setItem('csrf_token', token);
  }
  return token;
};

// Secure API calls with CSRF token and Content-Type validation
export const secureApiCall = async (url, options = {}) => {
  const csrfToken = getCSRFToken();
  
  const headers = {
    'Content-Type': 'application/json',
    'X-CSRF-Token': csrfToken,
    ...options.headers,
  };

  const response = await fetch(url, {
    ...options,
    headers,
    credentials: 'include', // Include cookies for session management
  });

  if (!response.ok) {
    const error = new Error(`API Error: ${response.status}`);
    error.status = response.status;
    throw error;
  }

  return response.json();
};

// Input validation utilities
export const validators = {
  email: (email) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email),
  password: (password) => password.length >= 12,
  workoutType: (type) => ['Strength', 'Cardio', 'Flexibility'].includes(type),
  duration: (duration) => typeof duration === 'number' && duration > 0 && duration <= 14400, // Max 4 hours
  calories: (calories) => typeof calories === 'number' && calories >= 0 && calories <= 10000,
};

// Log security events (for monitoring)
export const logSecurityEvent = (event, details = {}) => {
  if (process.env.NODE_ENV !== 'production') {
    console.warn(`[SECURITY] ${event}`, details);
  }
  // In production, send to security monitoring service
};

// Rate limiting helper
export const createRateLimiter = (maxAttempts = 5, windowMs = 15 * 60 * 1000) => {
  const attempts = new Map();

  return (key) => {
    const now = Date.now();
    const userAttempts = attempts.get(key) || [];
    
    // Remove old attempts outside window
    const recentAttempts = userAttempts.filter(time => now - time < windowMs);
    
    if (recentAttempts.length >= maxAttempts) {
      return { allowed: false, retryAfter: Math.ceil((windowMs - (now - recentAttempts[0])) / 1000) };
    }
    
    recentAttempts.push(now);
    attempts.set(key, recentAttempts);
    
    return { allowed: true };
  };
};
