import React, { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { logSecurityEvent } from '../utils/security';

export default function SAMLCallback() {
  const navigate = useNavigate();

  useEffect(() => {
    const handleSAMLResponse = async () => {
      try {
        const samlResponse = document.querySelector('[name="SAMLResponse"]')?.value;
        
        if (!samlResponse) {
          throw new Error('No SAML response received');
        }

        const response = await fetch('http://localhost:3001/auth/saml/callback', {
          method: 'POST',
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          credentials: 'include',
          body: new URLSearchParams({ SAMLResponse: samlResponse }).toString(),
        });

        if (!response.ok) {
          throw new Error(`SAML callback failed: ${response.statusText}`);
        }

        navigate('/dashboard');
      } catch (err) {
        logSecurityEvent('SAML callback error', { error: err.message });
        navigate('/auth/login');
      }
    };

    handleSAMLResponse();
  }, [navigate]);

  return <div>Processing SAML authentication...</div>;
}
