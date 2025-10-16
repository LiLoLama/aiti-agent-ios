import { Bars3Icon, MagnifyingGlassIcon } from '@heroicons/react/24/outline';
import clsx from 'clsx';

interface ChatHeaderProps {
  agentName: string;
  agentRole: string;
  agentStatus: 'online' | 'offline' | 'busy';
  onOpenOverview: () => void;
  agentAvatar: string;
  userName?: string;
  userAvatar?: string;
  onOpenProfile?: () => void;
  onToggleSearch?: () => void;
  isSearchOpen?: boolean;
}

const statusCopy: Record<ChatHeaderProps['agentStatus'], string> = {
  online: 'Verfügbar',
  offline: 'Offline',
  busy: 'Beschäftigt'
};

export function ChatHeader({
  agentName,
  agentRole,
  agentStatus,
  onOpenOverview,
  agentAvatar,
  userName,
  userAvatar,
  onOpenProfile,
  onToggleSearch,
  isSearchOpen
}: ChatHeaderProps) {
  const statusColor = (() => {
    switch (agentStatus) {
      case 'online':
        return 'bg-emerald-400';
      case 'busy':
        return 'bg-amber-400';
      default:
        return 'bg-zinc-500';
    }
  })();

  return (
    <header className="sticky top-0 z-30 flex items-center justify-between border-b border-white/10 bg-[#161616]/80 backdrop-blur-xl px-4 py-4 md:px-8">
      <div className="flex items-center gap-4">
        <button
          className="lg:hidden rounded-full bg-white/10 p-2 text-white/80 transition hover:bg-white/20"
          onClick={onOpenOverview}
        >
          <Bars3Icon className="h-5 w-5" />
        </button>
        <div className="relative h-14 w-14 overflow-hidden rounded-2xl border border-white/10 shadow-lg">
          <img src={agentAvatar} alt={agentName} className="h-full w-full object-cover" />
          <span className={clsx('absolute bottom-1 right-1 h-3 w-3 rounded-full border border-black/60', statusColor)} />
        </div>
        <div>
          <h1 className="text-lg font-semibold text-white md:text-xl">{agentName}</h1>
          <p className="text-sm text-white/60">{agentRole}</p>
          <div className="mt-1 flex items-center gap-2 text-xs text-white/40">
            <span className={clsx('h-1.5 w-1.5 rounded-full', statusColor)} />
            {statusCopy[agentStatus]}
          </div>
        </div>
      </div>
      <div className="flex items-center gap-3">
        {onToggleSearch && (
          <button
            type="button"
            onClick={onToggleSearch}
            className="inline-flex items-center justify-center rounded-full border border-white/10 bg-white/[0.05] p-2 text-white/70 transition hover:bg-white/10 lg:hidden"
            aria-label={isSearchOpen ? 'Suche schließen' : 'Suche öffnen'}
          >
            <MagnifyingGlassIcon className="h-5 w-5" />
          </button>
        )}
        {userName && (
          <button
            onClick={onOpenProfile}
            className="group flex items-center gap-3 rounded-full border border-white/10 bg-white/[0.05] px-3 py-2 text-left text-white/70 transition hover:bg-white/10"
          >
            <div className="relative h-10 w-10 overflow-hidden rounded-2xl border border-white/10">
              <img src={userAvatar} alt={userName} className="h-full w-full object-cover" />
            </div>
            <div className="hidden text-sm font-semibold sm:block">
              <p className="text-white">{userName}</p>
              <p className="text-xs text-white/40 group-hover:text-white/60">Mein Profil</p>
            </div>
          </button>
        )}
      </div>
    </header>
  );
}
