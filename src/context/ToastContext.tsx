import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode
} from 'react';
import { createPortal } from 'react-dom';
import {
  CheckCircleIcon,
  ExclamationTriangleIcon,
  InformationCircleIcon,
  XMarkIcon
} from '@heroicons/react/24/outline';
import clsx from 'clsx';

type ToastType = 'success' | 'error' | 'info';

interface ShowToastOptions {
  type?: ToastType;
  title: string;
  description?: string;
  duration?: number;
}

interface Toast extends Required<ShowToastOptions> {
  id: string;
  createdAt: number;
}

interface ToastContextValue {
  showToast: (options: ShowToastOptions) => string;
  dismissToast: (id: string) => void;
}

const ToastContext = createContext<ToastContextValue | undefined>(undefined);

const DEFAULT_DURATION = 4000;
const MAX_TOASTS = 4;

function createToastIcon(type: ToastType) {
  switch (type) {
    case 'success':
      return <CheckCircleIcon className="h-5 w-5 text-emerald-300" aria-hidden="true" />;
    case 'error':
      return <ExclamationTriangleIcon className="h-5 w-5 text-rose-300" aria-hidden="true" />;
    default:
      return <InformationCircleIcon className="h-5 w-5 text-sky-300" aria-hidden="true" />;
  }
}

function generateToastId() {
  if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') {
    return crypto.randomUUID();
  }

  return `toast-${Math.random().toString(36).slice(2, 10)}`;
}

export function ToastProvider({ children }: { children: ReactNode }) {
  const [toasts, setToasts] = useState<Toast[]>([]);
  const timeoutsRef = useRef<Map<string, number>>(new Map());

  const dismissToast = useCallback((id: string) => {
    setToasts((previous) => previous.filter((toast) => toast.id !== id));
    if (typeof window !== 'undefined') {
      const timeoutId = timeoutsRef.current.get(id);
      if (typeof timeoutId === 'number') {
        window.clearTimeout(timeoutId);
        timeoutsRef.current.delete(id);
      }
    }
  }, []);

  const showToast = useCallback(
    ({ type = 'info', title, description, duration = DEFAULT_DURATION }: ShowToastOptions) => {
      const id = generateToastId();
      const toast: Toast = {
        id,
        type,
        title,
        description: description ?? '',
        duration,
        createdAt: Date.now()
      };

      setToasts((previous) => {
        const existing = previous.filter((entry) => entry.id !== id);
        const limited = existing.slice(-MAX_TOASTS + 1);
        return [...limited, toast];
      });

      if (typeof window !== 'undefined') {
        const timeoutId = window.setTimeout(() => {
          dismissToast(id);
        }, duration);
        timeoutsRef.current.set(id, timeoutId);
      }

      return id;
    },
    [dismissToast]
  );

  useEffect(() => {
    return () => {
      if (typeof window === 'undefined') {
        return;
      }

      timeoutsRef.current.forEach((timeoutId) => {
        window.clearTimeout(timeoutId);
      });
      timeoutsRef.current.clear();
    };
  }, []);

  const value = useMemo<ToastContextValue>(
    () => ({
      showToast,
      dismissToast
    }),
    [dismissToast, showToast]
  );

  const portal =
    typeof document !== 'undefined'
      ? createPortal(
          <div className="pointer-events-none fixed inset-0 z-[1000] flex flex-col items-end gap-3 p-4 sm:p-6">
            {toasts.map((toast) => (
              <div
                key={toast.id}
                className={clsx(
                  'pointer-events-auto w-full max-w-sm overflow-hidden rounded-2xl border px-4 py-3 shadow-glow transition sm:max-w-md',
                  toast.type === 'success' && 'border-emerald-500/40 bg-emerald-500/10',
                  toast.type === 'error' && 'border-rose-500/40 bg-rose-500/10',
                  toast.type === 'info' && 'border-sky-500/40 bg-sky-500/10'
                )}
                role="status"
                aria-live="polite"
              >
                <div className="flex items-start gap-3">
                  <div className="mt-0.5 flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-black/20">
                    {createToastIcon(toast.type)}
                  </div>
                  <div className="flex-1 text-left text-sm text-white">
                    <p className="font-semibold">{toast.title}</p>
                    {toast.description && <p className="mt-1 text-xs text-white/70">{toast.description}</p>}
                  </div>
                  <button
                    type="button"
                    onClick={() => dismissToast(toast.id)}
                    className="text-white/60 transition hover:text-white"
                    aria-label="Benachrichtigung schließen"
                  >
                    <XMarkIcon className="h-4 w-4" />
                  </button>
                </div>
              </div>
            ))}
          </div>,
          document.body
        )
      : null;

  return (
    <ToastContext.Provider value={value}>
      {children}
      {portal}
    </ToastContext.Provider>
  );
}

export function useToast() {
  const context = useContext(ToastContext);
  if (!context) {
    throw new Error('useToast muss innerhalb eines ToastProvider verwendet werden.');
  }

  return context;
}
