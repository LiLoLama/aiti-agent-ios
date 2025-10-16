import { Chat } from '../data/sampleChats';
import { ChatMessageBubble } from './ChatMessageBubble';
import { TypingIndicator } from './TypingIndicator';

interface ChatTimelineProps {
  chat: Chat;
  agentAvatar: string;
  userAvatar: string;
  isAwaitingResponse?: boolean;
  emptyStateMessage?: string;
}

export function ChatTimeline({
  chat,
  agentAvatar,
  userAvatar,
  isAwaitingResponse,
  emptyStateMessage
}: ChatTimelineProps) {
  const hasMessages = chat.messages.length > 0;

  return (
    <section className="relative flex-1 min-h-0 overflow-hidden">
      <div className="relative h-full overflow-y-auto">
        <div className="flex flex-col gap-6 px-4 py-6 md:px-8">
          {hasMessages ? (
            chat.messages.map((message) => (
              <ChatMessageBubble
                key={message.id}
                message={message}
                isAgent={message.author === 'agent'}
                agentAvatar={agentAvatar}
                userAvatar={userAvatar}
              />
            ))
          ) : emptyStateMessage ? (
            <div className="rounded-3xl border border-dashed border-white/10 bg-white/5 px-6 py-8 text-center text-sm text-white/60">
              {emptyStateMessage}
            </div>
          ) : null}

          {isAwaitingResponse && (
            <div className="flex justify-start">
              <TypingIndicator />
            </div>
          )}
        </div>
      </div>
    </section>
  );
}
