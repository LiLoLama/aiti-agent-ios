import { FormEvent, useState } from 'react';
import { Link, Navigate, useLocation, useNavigate, type Location } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import aitiLogo from '../assets/aiti-logo.svg';

interface FormState {
  email: string;
  password: string;
  name: string;
  confirmPassword: string;
}

type AuthMode = 'login' | 'register';

const initialFormState: FormState = {
  email: '',
  password: '',
  name: '',
  confirmPassword: ''
};

export function LoginPage() {
  const { currentUser, login, register, isLoading } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const [mode, setMode] = useState<AuthMode>('login');
  const [formState, setFormState] = useState<FormState>(initialFormState);
  const [status, setStatus] = useState<'idle' | 'loading'>('idle');
  const [error, setError] = useState<string | null>(null);
  const [infoMessage, setInfoMessage] = useState<string | null>(null);

  const redirectPath = ((location.state as { from?: Location })?.from?.pathname) ?? '/';

  if (isLoading) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-[#0c0c0c] px-4 py-10 text-white">
        <p className="text-sm text-white/70">Authentifizierung wird geladen …</p>
      </div>
    );
  }

  if (currentUser) {
    return <Navigate to={redirectPath} replace />;
  }

  const handleChange = (field: keyof FormState, value: string) => {
    setFormState((prev) => ({ ...prev, [field]: value }));
  };

  const resetForm = () => {
    setFormState(initialFormState);
  };

  const handleSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setStatus('loading');
    setError(null);
    setInfoMessage(null);
    let registrationSucceeded = false;

    try {
      if (mode === 'login') {
        await login({ email: formState.email, password: formState.password });
        navigate(redirectPath, { replace: true });
      } else {
        if (formState.password !== formState.confirmPassword) {
          throw new Error('Die Passwörter stimmen nicht überein.');
        }

        const { sessionExists } = await register({
          name: formState.name,
          email: formState.email,
          password: formState.password
        });

        if (sessionExists) {
          setInfoMessage(
            'Account angelegt! Wir haben dir eine E-Mail zur Bestätigung gesendet. Du wirst direkt weitergeleitet.'
          );
          registrationSucceeded = true;
          navigate('/profile', { replace: true, state: { onboarding: true } });
        } else {
          setInfoMessage(
            'Account angelegt! Bitte bestätige deine E-Mail und melde dich danach mit deinen Zugangsdaten an.'
          );
          registrationSucceeded = true;
        }
      }
    } catch (submissionError) {
      const message =
        submissionError instanceof Error
          ? submissionError.message
          : 'Es ist ein unbekannter Fehler aufgetreten.';
      setError(message);
    } finally {
      setStatus('idle');
      if (registrationSucceeded) {
        resetForm();
      }
    }
  };

  const isLogin = mode === 'login';

  return (
    <div className="flex min-h-screen items-center justify-center bg-[#0c0c0c] px-4 py-10">
      <div className="relative w-full max-w-5xl overflow-hidden rounded-[32px] border border-white/10 bg-[#141414]/90 shadow-2xl">
        <div className="grid grid-cols-1 md:grid-cols-[1.1fr_0.9fr]">
          <div className="relative hidden md:block">
            <div className="absolute inset-0 bg-gradient-to-br from-brand-gold/30 via-brand-deep/40 to-brand-gold/20" />
            <div className="relative flex h-full flex-col justify-between p-10 text-white">
              <div>
                <img src={aitiLogo} alt="AITI Explorer" className="h-12" />
                <h1 className="mt-10 text-3xl font-semibold leading-tight">
                  Willkommen beim AITI Explorer Agent
                </h1>
                <p className="mt-4 text-sm text-white/70">
                  Steuere deine AI-Workflows, verwalte Agents und behalte die Aktivitäten deines Teams im Blick – alles in einem Ort.
                </p>
              </div>
              <div className="rounded-3xl bg-black/20 p-6 backdrop-blur">
                <p className="text-xs uppercase tracking-[0.4em] text-white/60">Highlights</p>
                <ul className="mt-3 space-y-2 text-sm text-white/80">
                  <li>• Intuitive Chat-Oberfläche für Agentensteuerung</li>
                  <li>• Strukturierte Verwaltung deiner Chats</li>
                  <li>• Individuelle Agent Anpassung</li>
                </ul>
              </div>
            </div>
          </div>

          <div className="relative bg-[#121212]/95 p-8 text-white md:p-10">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-xs uppercase tracking-[0.35em] text-white/50">{isLogin ? 'Login' : 'Registrieren'}</p>
                <h2 className="mt-2 text-2xl font-semibold">
                  {isLogin ? 'Schön, dich wiederzusehen!' : 'Lass uns starten.'}
                </h2>
              </div>
              <Link to="/" className="text-xs text-white/40 hover:text-white/70">
                Zurück zur Landingpage
              </Link>
            </div>

            <div className="mt-6 flex items-center gap-2 rounded-full bg-white/5 p-1 text-xs font-medium">
              <button
                className={`flex-1 rounded-full px-4 py-2 transition ${
                  isLogin ? 'bg-gradient-to-r from-brand-gold via-brand-deep to-brand-gold text-black font-semibold shadow-glow' : 'text-white/60'
                }`}
                onClick={() => {
                  setMode('login');
                  resetForm();
                  setError(null);
                  setInfoMessage(null);
                }}
              >
                Anmelden
              </button>
              <button
                className={`flex-1 rounded-full px-4 py-2 transition ${
                  !isLogin ? 'bg-gradient-to-r from-brand-gold via-brand-deep to-brand-gold text-black font-semibold shadow-glow' : 'text-white/60'
                }`}
                onClick={() => {
                  setMode('register');
                  resetForm();
                  setError(null);
                  setInfoMessage(null);
                }}
              >
                Account erstellen
              </button>
            </div>

            <form className="mt-8 space-y-5" onSubmit={handleSubmit}>
              {!isLogin && (
                <div>
                  <label className="text-xs font-medium uppercase tracking-[0.35em] text-white/40">Name</label>
                  <input
                    type="text"
                    className="mt-2 w-full rounded-2xl border border-white/10 bg-[#1b1b1b] px-4 py-3 text-sm text-white focus:border-brand-gold focus:outline-none"
                    placeholder="Wie dürfen wir dich nennen?"
                    value={formState.name}
                    onChange={(event) => handleChange('name', event.target.value)}
                    required
                  />
                </div>
              )}

              <div>
                <label className="text-xs font-medium uppercase tracking-[0.35em] text-white/40">E-Mail</label>
                <input
                  type="email"
                  className="mt-2 w-full rounded-2xl border border-white/10 bg-[#1b1b1b] px-4 py-3 text-sm text-white focus:border-brand-gold focus:outline-none"
                  placeholder="name@example.com"
                  value={formState.email}
                  onChange={(event) => handleChange('email', event.target.value)}
                  required
                />
              </div>

              <div>
                <label className="text-xs font-medium uppercase tracking-[0.35em] text-white/40">Passwort</label>
                <input
                  type="password"
                  className="mt-2 w-full rounded-2xl border border-white/10 bg-[#1b1b1b] px-4 py-3 text-sm text-white focus:border-brand-gold focus:outline-none"
                  placeholder="••••••••"
                  value={formState.password}
                  onChange={(event) => handleChange('password', event.target.value)}
                  required
                />
              </div>

              {!isLogin && (
                <div>
                  <label className="text-xs font-medium uppercase tracking-[0.35em] text-white/40">Passwort bestätigen</label>
                  <input
                    type="password"
                    className="mt-2 w-full rounded-2xl border border-white/10 bg-[#1b1b1b] px-4 py-3 text-sm text-white focus:border-brand-gold focus:outline-none"
                    placeholder="••••••••"
                    value={formState.confirmPassword}
                    onChange={(event) => handleChange('confirmPassword', event.target.value)}
                    required
                  />
                </div>
              )}

              {error && (
                <div className="rounded-2xl border border-red-500/40 bg-red-500/10 px-4 py-3 text-sm text-red-200">
                  {error}
                </div>
              )}

              {infoMessage && (
                <div className="rounded-2xl border border-emerald-500/40 bg-emerald-500/10 px-4 py-3 text-sm text-emerald-200">
                  {infoMessage}
                </div>
              )}

              <button
                type="submit"
                disabled={status === 'loading'}
                className="w-full rounded-full bg-gradient-to-r from-brand-gold via-brand-deep to-brand-gold px-6 py-3 text-sm font-semibold text-black shadow-glow transition hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-60"
              >
                {status === 'loading'
                  ? isLogin
                    ? 'Anmeldung läuft …'
                    : 'Account wird erstellt …'
                  : isLogin
                    ? 'Jetzt einloggen'
                    : 'Account anlegen'}
              </button>

              {isLogin && (
                <p className="text-xs text-white/40">
                  Noch kein Zugang?{' '}
                  <button
                    type="button"
                    className="text-brand-gold hover:underline"
                    onClick={() => {
                      setMode('register');
                      resetForm();
                      setError(null);
                      setInfoMessage(null);
                    }}
                  >
                    Erstelle deinen Account
                  </button>
                </p>
              )}
            </form>
          </div>
        </div>
      </div>
    </div>
  );
}
