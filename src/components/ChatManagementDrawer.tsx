import {
  XMarkIcon,
  PencilIcon,
  TrashIcon,
  FolderPlusIcon,
  Squares2X2Icon
} from '@heroicons/react/24/outline';
import clsx from 'clsx';
import { Chat } from '../data/sampleChats';

interface ChatManagementDrawerProps {
  chats: Chat[];
  isOpen: boolean;
  onClose: () => void;
  onSelectChat: (chatId: string) => void;
}

export function ChatManagementDrawer({ chats, isOpen, onClose, onSelectChat }: ChatManagementDrawerProps) {
  return (
    <div
      className={clsx(
        'fixed inset-0 z-40 flex lg:hidden transition-all duration-300',
        isOpen ? 'pointer-events-auto' : 'pointer-events-none'
      )}
    >
      <div
        className={clsx(
          'absolute inset-0 bg-black/60 backdrop-blur-sm transition-opacity',
          isOpen ? 'opacity-100' : 'opacity-0'
        )}
        onClick={onClose}
      />
      <div
        className={clsx(
          'ml-auto flex h-full w-full max-w-md flex-col border-l border-white/10 bg-[#121212] shadow-2xl transition-transform duration-300',
          isOpen ? 'translate-x-0' : 'translate-x-full'
        )}
      >
        <div className="flex items-center justify-between border-b border-white/10 px-6 py-5">
          <div>
            <p className="text-xs uppercase tracking-[0.3em] text-white/40">Management</p>
            <h3 className="text-lg font-semibold text-white">Chats &amp; Workflows</h3>
          </div>
          <button
            onClick={onClose}
            className="rounded-full bg-white/5 p-2 text-white/70 transition hover:bg-white/10"
          >
            <XMarkIcon className="h-5 w-5" />
          </button>
        </div>
        <div className="flex-1 overflow-y-auto px-6 py-6 space-y-5">
          {chats.map((chat) => (
            <div
              key={chat.id}
              className="rounded-2xl border border-white/5 bg-white/[0.03] p-4 shadow-lg shadow-black/20"
            >
              <div className="flex items-start justify-between gap-3">
                <div>
                  <h4 className="text-base font-semibold text-white">{chat.name}</h4>
                  <p className="text-xs uppercase tracking-[0.2em] text-white/40">{chat.folder ?? 'Ohne Ordner'}</p>
                  <p className="mt-2 text-sm text-white/60">{chat.preview}</p>
                </div>
                <button
                  onClick={() => onSelectChat(chat.id)}
                  className="rounded-full bg-gradient-to-r from-brand-gold to-brand-deep px-3 py-1 text-xs font-semibold text-surface-base shadow-glow"
                >
                  Öffnen
                </button>
              </div>
              <div className="mt-4 grid grid-cols-3 gap-2 text-xs">
                <button className="flex items-center justify-center gap-2 rounded-xl bg-white/5 px-3 py-2 text-white/70 hover:bg-white/10">
                  <PencilIcon className="h-4 w-4" />
                  Umbenennen
                </button>
                <button className="flex items-center justify-center gap-2 rounded-xl bg-white/5 px-3 py-2 text-white/70 hover:bg-white/10">
                  <FolderPlusIcon className="h-4 w-4" />
                  Ordner
                </button>
                <button className="flex items-center justify-center gap-2 rounded-xl bg-white/5 px-3 py-2 text-rose-400 hover:bg-white/10">
                  <TrashIcon className="h-4 w-4" />
                  Löschen
                </button>
              </div>
            </div>
          ))}
        </div>
        <div className="border-t border-white/10 px-6 py-5">
          <button className="flex w-full items-center justify-center gap-2 rounded-2xl border border-dashed border-brand-gold/40 px-4 py-3 text-sm font-medium text-brand-gold hover:bg-brand-gold/10">
            <Squares2X2Icon className="h-5 w-5" />
            Neuen Ordner anlegen
          </button>
        </div>
      </div>
    </div>
  );
}
