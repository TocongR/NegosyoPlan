import { useEffect, useState } from 'react';
import { onAuthStateChanged, signOut } from 'firebase/auth';
import { doc, getDoc } from 'firebase/firestore';
import { auth, db } from './firebase.js';
import LoginPage from './LoginPage.jsx';
import ApplicationsPage from './ApplicationsPage.jsx';
import ApplicationPage from './ApplicationPage.jsx';

/** Reads "#/app/<uid>" from the address bar. Anything else is the list. */
function useHashRoute() {
  const read = () => {
    const m = window.location.hash.match(/^#\/app\/([^/?]+)/);
    return m ? { page: 'app', id: decodeURIComponent(m[1]) } : { page: 'list' };
  };
  const [route, setRoute] = useState(read);
  useEffect(() => {
    const on = () => setRoute(read());
    window.addEventListener('hashchange', on);
    return () => window.removeEventListener('hashchange', on);
  }, []);
  return route;
}

export default function App() {
  const [user, setUser] = useState(undefined); // undefined = still checking
  const [staff, setStaff] = useState(null); // staff/{uid} document, or null
  const [denied, setDenied] = useState('');
  const route = useHashRoute();

  useEffect(
    () =>
      onAuthStateChanged(auth, async (u) => {
        setDenied('');
        if (!u) {
          setStaff(null);
          setUser(null);
          return;
        }
        try {
          const s = await getDoc(doc(db, 'staff', u.uid));
          if (s.exists()) {
            setStaff({ uid: u.uid, email: u.email, ...s.data() });
          } else {
            setDenied(`${u.email} is not an OLEDIPO staff account.`);
            await signOut(auth);
          }
        } catch (e) {
          setDenied(`Could not check staff access: ${e.code || e.message}`);
          await signOut(auth);
        }
        setUser(u);
      }),
    [],
  );

  if (user === undefined) return <div className="center muted">Loading…</div>;
  if (!staff) return <LoginPage notice={denied} />;

  return (
    <div className="shell">
      <aside className="sidebar">
        <a href="#/" className="brand">
          <span className="logo">NP</span>
          <span className="brand-name">NegosyoPlan</span>
        </a>
        <div className="brand-sub">OLEDIPO Admin · EMBRACE Program</div>

        <nav className="nav">
          <a href="#/" className="nav-item on">
            MSME Passports
          </a>
        </nav>

        <div className="side-foot">
          Signed in as
          <br />
          <b>{staff.name || staff.email}</b> · Admin
          <button className="btn side-out" onClick={() => signOut(auth)}>
            Log out
          </button>
        </div>
      </aside>

      <main className="content">
        {route.page === 'app' ? <ApplicationPage id={route.id} staff={staff} /> : <ApplicationsPage />}
      </main>
    </div>
  );
}