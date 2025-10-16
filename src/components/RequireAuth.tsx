import { ArrowPathIcon } from '@heroicons/react/24/outline';
import { Navigate, Outlet, useLocation } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

export function RequireAuth() {
  const { currentUser, isLoading } = useAuth();
  const location = useLocation();

  if (isLoading) {
    const initials = currentUser?.name
      ? currentUser.name
          .split(' ')
          .map((part) => part.trim()[0])
          .filter(Boolean)
          .slice(0, 2)
          .join('')
          .toUpperCase()
      : null;

    return (
      <div className="flex min-h-screen items-center justify-center bg-[#111111] px-4 text-white/70">
        <div className="w-full max-w-sm rounded-3xl border border-white/10 bg-[#161616] p-8 text-center shadow-glow">
          <ArrowPathIcon className="mx-auto h-6 w-6 animate-spin text-white/70" />
          {currentUser ? (
            <>
              <p className="mt-4 text-sm text-white/60">Willkommen zurück</p>
              <div className="mt-4 flex items-center justify-center gap-3">
                {currentUser.avatarUrl ? (
                  <span className="h-12 w-12 overflow-hidden rounded-full border border-white/10 bg-white/10">
                    <img
                      src={currentUser.avatarUrl}
                      alt="Profilbild"
                      className="h-full w-full object-cover"
                    />
                  </span>
                ) : (
                  <span className="flex h-12 w-12 items-center justify-center rounded-full border border-white/10 bg-white/10 text-sm font-semibold uppercase text-white/70">
                    {initials || 'AI'}
                  </span>
                )}
                <div className="text-left">
                  <p className="text-base font-semibold text-white">{currentUser.name}</p>
                  <p className="text-xs text-white/40">{currentUser.email}</p>
                </div>
              </div>
              <p className="mt-4 text-xs text-white/50">Dein Arbeitsbereich wird vorbereitet …</p>
            </>
          ) : (
            <p className="mt-4 text-sm">Authentifizierung wird geladen …</p>
          )}
        </div>
      </div>
    );
  }

  if (!currentUser) {
    return <Navigate to="/login" replace state={{ from: location }} />;
  }

  if (!currentUser.isActive) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-[#111111] px-4">
        <div className="w-full max-w-lg rounded-3xl border border-white/10 bg-[#161616] p-8 text-center text-white shadow-glow">
          <h2 className="text-2xl font-semibold">Zugang deaktiviert</h2>
          <p className="mt-4 text-sm text-white/70">
            Dein Account wurde deaktiviert. Bitte wende dich an das AITI Admin-Team, um wieder Zugriff zu erhalten.
          </p>
        </div>
      </div>
    );
  }

  return <Outlet />;
}
