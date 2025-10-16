import { MicrophoneIcon, PaperClipIcon } from '@heroicons/react/24/outline';
import clsx from 'clsx';
import ReactMarkdown from 'react-markdown';
import type { Components } from 'react-markdown';
import remarkGfm from 'remark-gfm';
import { ChatMessage } from '../data/sampleChats';

interface ChatMessageBubbleProps {
  message: ChatMessage;
  isAgent: boolean;
  agentAvatar: string;
  userAvatar: string;
}

const markdownComponents: Components = {
  p({ children }) {
    return <p className="whitespace-pre-wrap leading-relaxed last:mb-0">{children}</p>;
  },
  strong({ children }) {
    return <strong className="font-semibold">{children}</strong>;
  },
  em({ children }) {
    return <em className="italic">{children}</em>;
  },
  code({ inline, children, ...props }: any) {
    if (inline) {
      return (
        <code
          {...props}
          className={clsx(
            'rounded bg-black/20 px-1 py-0.5 font-mono text-[0.85em]',
            props.className
          )}
        >
          {children}
        </code>
      );
    }

    return (
      <code
        {...props}
        className={clsx('block whitespace-pre-wrap font-mono text-sm', props.className)}
      >
        {children}
      </code>
    );
  },
  pre({ children }) {
    return <pre className="overflow-x-auto rounded-2xl bg-black/20 px-3 py-2">{children}</pre>;
  },
  a({ children, href }) {
    return (
      <a href={href} className="underline decoration-2 underline-offset-2">
        {children}
      </a>
    );
  },
  ul({ children }) {
    return <ul className="list-disc space-y-1 pl-5 text-left">{children}</ul>;
  },
  ol({ children }) {
    return <ol className="list-decimal space-y-1 pl-5 text-left">{children}</ol>;
  },
  li({ children }) {
    return <li className="whitespace-normal">{children}</li>;
  },
  blockquote({ children }) {
    return (
      <blockquote className="border-l-4 border-white/20 pl-4 italic opacity-90">
        {children}
      </blockquote>
    );
  },
  hr() {
    return <hr className="border-t border-white/10" />;
  },
};

export function ChatMessageBubble({ message, isAgent, agentAvatar, userAvatar }: ChatMessageBubbleProps) {
  const formatFileSize = (size?: number) => {
    if (!size) {
      return '';
    }

    if (size >= 1024 * 1024) {
      return `${(size / (1024 * 1024)).toFixed(1)} MB`;
    }

    if (size >= 1024) {
      return `${Math.round(size / 1024)} KB`;
    }

    return `${size} B`;
  };

  return (
    <div className={clsx('flex gap-3 md:gap-4', isAgent ? 'flex-row' : 'flex-row-reverse')}>
      <div className="h-10 w-10 rounded-xl overflow-hidden border border-white/10 shadow-lg">
        <img
          src={isAgent ? agentAvatar : userAvatar}
          alt={isAgent ? 'Agent Avatar' : 'User Avatar'}
          className="h-full w-full object-cover"
        />
      </div>
      <div className={clsx('max-w-3xl space-y-2', isAgent ? 'items-start text-left' : 'items-end text-right')}>
        <div
          className={clsx(
            'rounded-3xl px-5 py-4 text-sm leading-relaxed backdrop-blur-xl border border-white/5 shadow-lg/10',
            isAgent
              ? 'bg-[#2b2b2b] text-[#ffffff]'
              : 'bg-gradient-to-r from-brand-gold via-brand-deep to-brand-gold text-surface-base shadow-glow'
          )}
        >
          <div
            className={clsx(
              'space-y-3 break-words',
              isAgent ? 'text-left' : 'text-right'
            )}
          >
            <ReactMarkdown remarkPlugins={[remarkGfm]} components={markdownComponents}>
              {message.content}
            </ReactMarkdown>
          </div>
        </div>
        {message.attachments && message.attachments.length > 0 && (
          <div
            className={clsx(
              'space-y-2 text-xs',
              isAgent ? 'text-left text-[rgba(255,255,255,0.8)]' : 'text-right text-white/80'
            )}
          >
            {message.attachments.map((attachment) => {
              if (attachment.kind === 'audio') {
                return (
                  <div
                    key={attachment.id}
                    className="rounded-2xl border border-white/10 bg-white/5 p-3"
                  >
                    <div className="flex items-center justify-between gap-2">
                      <span className="inline-flex items-center gap-2 text-[#ffffff]">
                        <MicrophoneIcon className="h-4 w-4 text-brand-gold" />
                        Audio Nachricht
                      </span>
                      {typeof attachment.durationSeconds === 'number' ? (
                        <span className={clsx(isAgent ? 'text-[rgba(255,255,255,0.4)]' : 'text-white/40')}>
                          {attachment.durationSeconds.toFixed(1)}s
                        </span>
                      ) : null}
                    </div>
                    <audio
                      controls
                      src={attachment.url}
                      className="mt-2 w-full"
                    />
                  </div>
                );
              }

              return (
                <a
                  key={attachment.id}
                  href={attachment.url}
                  download={attachment.name}
                  className={clsx(
                    'flex items-center justify-between gap-3 rounded-2xl border border-white/10 bg-white/5 px-4 py-3 transition hover:bg-white/10',
                    isAgent ? 'text-[#ffffff]' : 'text-white'
                  )}
                >
                  <span className="flex items-center gap-2">
                    <PaperClipIcon className="h-4 w-4" />
                    <span className="max-w-[200px] truncate" title={attachment.name}>
                      {attachment.name}
                    </span>
                  </span>
                  <span className={clsx(isAgent ? 'text-[rgba(255,255,255,0.4)]' : 'text-white/40')}>
                    {formatFileSize(attachment.size)}
                  </span>
                </a>
              );
            })}
          </div>
        )}
        <span
          className={clsx(
            'text-xs',
            isAgent ? 'text-[rgba(255,255,255,0.3)]' : 'text-white/30'
          )}
        >
          {message.timestamp}
        </span>
      </div>
    </div>
  );
}
