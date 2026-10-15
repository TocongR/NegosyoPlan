import { useState } from 'react';
import { signInWithEmailAndPassword, sendPasswordResetEmail } from 'firebase/auth';
import { auth } from './firebase.js';

const messages = {
  'auth/invalid-credential': 'Wrong email or password.',
  'auth/invalid-email': 'That email does not look right.',
  'auth/too-many-requests': 'Too many tries. Wait a few minutes.',
  'auth/network-request-failed': 'No internet connection.',
};

export default function LoginPage({ notice }) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [info, setInfo] = useState('');

  async function submit(e) {
    e.preventDefault();
    setBusy(true);
    setError('');
    setInfo('');
    try {
      await signInWithEmailAndPassword(auth, email.trim(), password);
    } catch (err) {
      setError(messages[err.code] || `Could not log in (${err.code}).`);
    }
    setBusy(false);
  }

  async function reset() {
    if (!email.trim()) return setError('Type your email first, then click "Forgot password".');
    try {
      await sendPasswordResetEmail(auth, email.trim());
      setInfo('A reset link was sent to your email.');
    } catch (err) {
      setError(messages[err.code] || `Could not send the link (${err.code}).`);
    }
  }

  return (
    <div className="login-wrap">
      <form className="card login" onSubmit={submit}>
        <div className="brand big">
          
          <span>
            NegosyoPlan <b>Admin</b>
            <small>OLEDIPO · EMBRACE</small>
          </span>
        </div>
        {notice && <div className="alert red">{notice}</div>}
        {error && <div className="alert red">{error}</div>}
        {info && <div className="alert green">{info}</div>}
        <label>
          Email
          <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} autoComplete="username" required />
        </label>
        <label>
          Password
          <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} autoComplete="current-password" required />
        </label>
        <button className="btn primary" disabled={busy}>
          {busy ? 'Logging in…' : 'Log in'}
        </button>
        {/* <button type="button" className="link" onClick={reset}>
          Forgot password
        </button> */}
      </form>
    </div>
  );
}