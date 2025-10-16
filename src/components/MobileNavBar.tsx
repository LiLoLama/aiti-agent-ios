import { PlusCircleIcon, Squares2X2Icon, UserCircleIcon } from '@heroicons/react/24/outline';

interface MobileNavBarProps {
  onNewChat: () => void;
  onToggleOverview: () => void;
  onOpenProfile: () => void;
}

export function MobileNavBar({ onNewChat, onToggleOverview, onOpenProfile }: MobileNavBarProps) {
  return (
    <nav className="lg:hidden fixed inset-x-0 bottom-0 z-30 border-t border-white/10 bg-[#141414]/95 backdrop-blur-xl">
      <div className="mx-auto flex max-w-3xl items-center justify-around px-6 py-3 text-white/70">
        <button
          onClick={onToggleOverview}
          className="flex flex-col items-center text-xs font-medium gap-1"
        >
          <Squares2X2Icon className="h-6 w-6" />
          Übersicht
        </button>
        <button
          onClick={onNewChat}
          className="flex -translate-y-6 flex-col items-center rounded-full bg-gradient-to-r from-brand-gold via-brand-deep to-brand-gold p-4 text-xs font-semibold text-surface-base shadow-glow"
        >
          <PlusCircleIcon className="h-6 w-6" />
          Neu
        </button>
        <button
          onClick={onOpenProfile}
          className="flex flex-col items-center text-xs font-medium gap-1"
        >
          <UserCircleIcon className="h-6 w-6" />
          Profil
        </button>
      </div>
    </nav>
  );
}
