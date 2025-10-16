import { useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { ChatHeader } from '../components/ChatHeader';
import { ChatTimeline } from '../components/ChatTimeline';
import { ChatInput, ChatInputSubmission } from '../components/ChatInput';
import { ChatOverviewPanel } from '../components/ChatOverviewPanel';
import { Chat, ChatAttachment, ChatMessage } from '../data/sampleChats';
import {
  ChevronDoubleLeftIcon,
  ChevronDoubleRightIcon,
  MagnifyingGlassIcon
} from '@heroicons/react/24/outline';

import agentAvatar from '../assets/agent-avatar.png';
import userAvatar from '../assets/default-user.svg';
import { AgentSettings } from '../types/settings';
import { loadAgentSettings } from '../utils/storage';
import { sendAudioWebhookNotification, sendWebhookMessage } from '../utils/webhook';
import { applyColorScheme } from '../utils/theme';
import { useAuth } from '../context/AuthContext';
import { useToast } from '../context/ToastContext';
import {
  deleteAgentConversation,
  fetchAgentConversations,
  mapConversationToChat,
  upsertAgentConversation,
  type AgentConversationUpdatePayload
} from '../services/chatService';
import {
  applyIntegrationSecretToSettings,
  fetchIntegrationSecret
} from '../services/integrationSecretsService';
import { uploadAndPersistAudioMessage } from '../services/audioMessageService';

const formatTimestamp = (date: Date) =>
  date.toLocaleTimeString('de-DE', {
    hour: '2-digit',
    minute: '2-digit'
  });

const blobToDataUrl = (blob: Blob): Promise<string> =>
  new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => {
      if (typeof reader.result === 'string') {
        resolve(reader.result);
      } else {
        reject(new Error('Datei konnte nicht gelesen werden.'));
      }
    };
    reader.onerror = () => reject(reader.error ?? new Error('Unbekannter Fehler beim Lesen der Datei.'));
    reader.readAsDataURL(blob);
  });

const toPreview = (value: string) => (value.length > 140 ? `${value.slice(0, 137)}…` : value);

const createId = () => {
  if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') {
    return crypto.randomUUID();
  }

  return Math.random().toString(36).slice(2, 11);
};

const createInitialChat = (agentId: string, agentName: string, greeting: string): { chat: Chat; iso: string } => {
  const timestamp = new Date();
  const iso = timestamp.toISOString();
  const initialMessage: ChatMessage = {
    id: createId(),
    author: 'agent',
    content: greeting,
    timestamp: formatTimestamp(timestamp)
  };

  return {
    chat: {
      id: agentId,
      conversationId: null,
      name: agentName,
      lastUpdated: formatTimestamp(timestamp),
      preview: toPreview(greeting),
      messages: [initialMessage]
    },
    iso
  };
};

export function ChatPage() {
  const navigate = useNavigate();
  const { currentUser } = useAuth();
  const { showToast } = useToast();
  const [settings, setSettings] = useState<AgentSettings>(() => loadAgentSettings());
  const [conversations, setConversations] = useState<Record<string, Chat>>({});
  const [activeAgentId, setActiveAgentId] = useState<string | null>(null);
  const [isWorkspaceCollapsed, setWorkspaceCollapsed] = useState(false);
  const [isMobileWorkspaceOpen, setMobileWorkspaceOpen] = useState(false);
  const [isLoadingChats, setIsLoadingChats] = useState(false);
  const [pendingResponseAgentId, setPendingResponseAgentId] = useState<string | null>(null);
  const [isSearchOpen, setSearchOpen] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');

  useEffect(() => {
    if (!currentUser?.id) {
      return;
    }

    let isActive = true;

    const syncIntegrationSecrets = async () => {
      try {
        const record = await fetchIntegrationSecret(currentUser.id);
        if (!isActive) {
          return;
        }

        setSettings((previous) => applyIntegrationSecretToSettings(previous, record));
      } catch (error) {
        console.error('Integrations-Secrets konnten nicht geladen werden.', error);
      }
    };

    void syncIntegrationSecrets();

    return () => {
      isActive = false;
    };
  }, [currentUser?.id]);

  useEffect(() => {
    if (!currentUser || currentUser.agents.length === 0) {
      setActiveAgentId(null);
      return;
    }

    setActiveAgentId((previous) => {
      if (previous && currentUser.agents.some((agent) => agent.id === previous)) {
        return previous;
      }

      return currentUser.agents[0].id;
    });
  }, [currentUser]);

  useEffect(() => {
    applyColorScheme(settings.colorScheme);
  }, [settings.colorScheme]);

  const selectedAgent = useMemo(() => {
    if (!currentUser || currentUser.agents.length === 0) {
      return null;
    }

    if (activeAgentId) {
      const found = currentUser.agents.find((agent) => agent.id === activeAgentId);
      if (found) {
        return found;
      }
    }

    return currentUser.agents[0];
  }, [currentUser, activeAgentId]);

  const defaultAgentAvatar = useMemo(
    () => settings.agentAvatarImage ?? agentAvatar,
    [settings.agentAvatarImage]
  );

  const activeAgentAvatar = selectedAgent?.avatarUrl ?? defaultAgentAvatar;
  const activeAgentName = selectedAgent?.name?.trim() || 'AITI Agent';
  const activeAgentRole = selectedAgent?.description?.trim() || 'Dein digitaler Companion';
  const accountAvatar = currentUser?.avatarUrl ?? userAvatar;
  const hasAgents = Boolean(selectedAgent);

  useEffect(() => {
    if (!currentUser) {
      setConversations({});
      setIsLoadingChats(false);
      return;
    }

    let isSubscribed = true;
    const profileId = currentUser.id;

    const loadConversations = async () => {
      setIsLoadingChats(true);

      try {
        const records = await fetchAgentConversations(profileId);
        if (!isSubscribed) {
          return;
        }

        const recordMap = new Map(records.map((record) => [record.agent_id, record] as const));
        const knownAgentIds = new Set(currentUser.agents.map((agent) => agent.id));
        const operations: Promise<unknown>[] = [];
        const nextConversations: Record<string, Chat> = {};
        const defaultPreview = 'Beschreibe dein nächstes Projekt und starte den AI Agent.';
        const userName = (currentUser.name ?? settings.profileName ?? '').trim();
        const greeting = userName
          ? `Hallo ${userName}! Wie kann ich dir heute helfen?`
          : 'Hallo! Wie kann ich dir heute helfen?';

        currentUser.agents.forEach((agent) => {
          const agentId = agent.id;
          const agentName = agent.name?.trim().length ? agent.name.trim() : 'AITI Agent';
          const record = recordMap.get(agentId);

          if (!record || record.messages.length === 0) {
            const { chat, iso } = createInitialChat(agentId, agentName, greeting);
            nextConversations[agentId] = chat;
            operations.push(
              upsertAgentConversation(profileId, agentId, {
                messages: chat.messages,
                summary: chat.preview,
                lastMessageAt: iso,
                agentName,
                agentDescription: agent.description ?? '',
                agentAvatarUrl: agent.avatarUrl ?? null,
                agentWebhookUrl: agent.webhookUrl ?? null,
                agentTools: agent.tools
              })
                .then((persistedConversation) => {
                  nextConversations[agentId] = {
                    ...nextConversations[agentId],
                    conversationId: persistedConversation.id
                  };
                })
                .catch((error) => {
                  console.error('Initiale Konversation konnte nicht synchronisiert werden.', error);
                })
            );
            return;
          }

          const chat = mapConversationToChat(record, agentName, defaultPreview);
          nextConversations[agentId] = chat;

          const metadataUpdates: AgentConversationUpdatePayload = {};
          if (record.agent_name !== agentName) {
            metadataUpdates.agentName = agentName;
          }
          if ((record.agent_description ?? '') !== (agent.description ?? '')) {
            metadataUpdates.agentDescription = agent.description ?? '';
          }
          if ((record.agent_avatar_url ?? null) !== (agent.avatarUrl ?? null)) {
            metadataUpdates.agentAvatarUrl = agent.avatarUrl ?? null;
          }
          if ((record.agent_webhook_url ?? null) !== (agent.webhookUrl ?? null)) {
            metadataUpdates.agentWebhookUrl = agent.webhookUrl ?? null;
          }
          const existingTools = record.agent_tools ?? [];
          const desiredTools = agent.tools ?? [];
          const toolsChanged =
            existingTools.length !== desiredTools.length ||
            existingTools.some((tool, index) => tool !== desiredTools[index]);

          if (toolsChanged) {
            metadataUpdates.agentTools = desiredTools;
          }

          if (Object.keys(metadataUpdates).length > 0) {
            operations.push(
              upsertAgentConversation(profileId, agentId, {
                ...metadataUpdates
              })
                .then((persistedConversation) => {
                  nextConversations[agentId] = {
                    ...nextConversations[agentId],
                    conversationId: persistedConversation.id
                  };
                })
                .catch((error) => {
                  console.error('Konversations-Metadaten konnten nicht synchronisiert werden.', error);
                })
            );
          }
        });

        records.forEach((record) => {
          if (!knownAgentIds.has(record.agent_id)) {
            operations.push(deleteAgentConversation(profileId, record.agent_id));
          }
        });

        if (operations.length > 0) {
          await Promise.allSettled(operations);
        }

        if (!isSubscribed) {
          return;
        }

        setConversations(nextConversations);
        setActiveAgentId((previous) => {
          if (previous && nextConversations[previous]) {
            return previous;
          }

          const firstAgent = currentUser.agents[0];
          return firstAgent ? firstAgent.id : null;
        });
      } catch (error) {
        console.error('Chats konnten nicht geladen werden.', error);
        if (isSubscribed) {
          setConversations({});
        }
      } finally {
        if (isSubscribed) {
          setIsLoadingChats(false);
        }
      }
    };

    void loadConversations();

    return () => {
      isSubscribed = false;
    };
  }, [currentUser, settings.profileName]);

  useEffect(() => {
    if (!isSearchOpen) {
      setSearchQuery('');
    }
  }, [isSearchOpen]);

  const activeChat = useMemo(() => {
    if (!selectedAgent) {
      return null;
    }

    return conversations[selectedAgent.id] ?? null;
  }, [conversations, selectedAgent]);

  const normalizedQuery = searchQuery.trim().toLowerCase();
  const searchActive = isSearchOpen && normalizedQuery.length > 0;

  const visibleChat = useMemo(() => {
    if (!activeChat) {
      return null;
    }

    if (!searchActive) {
      return activeChat;
    }

    const filteredMessages = activeChat.messages.filter((message) =>
      message.content.toLowerCase().includes(normalizedQuery)
    );

    return {
      ...activeChat,
      messages: filteredMessages
    };
  }, [activeChat, normalizedQuery, searchActive]);

  const searchResultCount = searchActive ? visibleChat?.messages.length ?? 0 : null;

  const agentOverviewItems = useMemo(() => {
    if (!currentUser) {
      return [];
    }

    const defaultPreview = 'Beschreibe dein nächstes Projekt und starte den AI Agent.';

    return currentUser.agents.map((agent) => {
      const agentId = agent.id;
      const agentName = agent.name?.trim().length ? agent.name.trim() : 'AITI Agent';
      const conversation = conversations[agentId];

      return {
        id: agentId,
        name: agentName,
        description: agent.description ?? '',
        avatarUrl: agent.avatarUrl ?? null,
        preview: conversation?.preview ?? defaultPreview,
        lastUpdated: conversation?.lastUpdated
      };
    });
  }, [conversations, currentUser]);

  const handleOpenAgentCreation = () => {
    setMobileWorkspaceOpen(false);
    navigate('/profile', { state: { openAgentModal: 'create' } });
  };

  const handleSelectAgent = (agentId: string) => {
    setActiveAgentId(agentId);
    setMobileWorkspaceOpen(false);
  };

  const handleSendMessage = async (submission: ChatInputSubmission) => {
    if (!currentUser || !selectedAgent) {
      return;
    }

    const trimmedText = submission.text?.trim() ?? '';
    const hasContent = Boolean(trimmedText || submission.files.length > 0 || submission.audio);

    if (!hasContent) {
      return;
    }

    const agentId = selectedAgent.id;
    const existingChat = conversations[agentId];
    const defaultPreview = 'Beschreibe dein nächstes Projekt und starte den AI Agent.';

    let baseChat = existingChat;
    if (!baseChat) {
      const userName = (currentUser.name ?? settings.profileName ?? '').trim();
      const greeting = userName
        ? `Hallo ${userName}! Wie kann ich dir heute helfen?`
        : 'Hallo! Wie kann ich dir heute helfen?';
      const { chat, iso } = createInitialChat(
        agentId,
        selectedAgent.name?.trim().length ? selectedAgent.name.trim() : 'AITI Agent',
        greeting
      );
      baseChat = chat;
      setConversations((prev) => ({
        ...prev,
        [agentId]: chat
      }));
      try {
        const persistedConversation = await upsertAgentConversation(currentUser.id, agentId, {
          messages: chat.messages,
          summary: chat.preview,
          lastMessageAt: iso,
          agentName: chat.name,
          agentDescription: selectedAgent.description ?? '',
          agentAvatarUrl: selectedAgent.avatarUrl ?? null,
          agentWebhookUrl: selectedAgent.webhookUrl ?? null,
          agentTools: selectedAgent.tools
        });
        baseChat = {
          ...chat,
          conversationId: persistedConversation.id
        };
        setConversations((prev) => ({
          ...prev,
          [agentId]: baseChat
        }));
      } catch (error) {
        console.error('Initiale Konversation konnte nicht gespeichert werden.', error);
      }
    }

    if (!baseChat) {
      return;
    }

    const now = new Date();
    const files = submission.files ?? [];
    const audioRecording = submission.audio ?? null;

    const fileAttachments: ChatAttachment[] = await Promise.all(
      files.map(async (file) => ({
        id: createId(),
        name: file.name,
        size: file.size,
        type: file.type,
        url: await blobToDataUrl(file),
        kind: 'file' as const
      }))
    );

    const audioAttachments: ChatAttachment[] = audioRecording
      ? [
          {
            id: createId(),
            name: `Audio-${formatTimestamp(now)}`,
            size: audioRecording.blob.size,
            type: audioRecording.mimeType || 'audio/webm',
            url: await blobToDataUrl(audioRecording.blob),
            kind: 'audio' as const,
            durationSeconds: Number.isFinite(audioRecording.durationMs)
              ? Number((Math.max(0, audioRecording.durationMs) / 1000).toFixed(1))
              : undefined
          }
        ]
      : [];

    const attachments = [...fileAttachments, ...audioAttachments];

    const messageContent = trimmedText
      ? trimmedText
      : audioAttachments.length
      ? 'Audio Nachricht gesendet.'
      : attachments.length
      ? 'Datei gesendet.'
      : '';

    const userMessage: ChatMessage = {
      id: createId(),
      author: 'user',
      content: messageContent,
      timestamp: formatTimestamp(now),
      attachments: attachments.length ? attachments : undefined
    };

    const previewSource = trimmedText
      ? trimmedText
      : audioAttachments.length
      ? 'Audio Nachricht'
      : attachments[0]?.name ?? 'Neue Nachricht';
    const previewText = toPreview(previewSource);

    let chatAfterUserMessage: Chat = {
      id: baseChat.id,
      conversationId: baseChat.conversationId ?? null,
      name: baseChat.name,
      messages: [...baseChat.messages, userMessage],
      lastUpdated: formatTimestamp(now),
      preview: previewText
    };

    const previousConversations = conversations;

    setConversations((prev) => ({
      ...prev,
      [agentId]: chatAfterUserMessage
    }));
    setPendingResponseAgentId(agentId);

    try {
      const persistedConversation = await upsertAgentConversation(currentUser.id, agentId, {
        messages: chatAfterUserMessage.messages,
        summary: chatAfterUserMessage.preview,
        lastMessageAt: now.toISOString(),
        agentName: chatAfterUserMessage.name,
        agentDescription: selectedAgent.description ?? '',
        agentAvatarUrl: selectedAgent.avatarUrl ?? null,
        agentWebhookUrl: selectedAgent.webhookUrl ?? null,
        agentTools: selectedAgent.tools
      });
      chatAfterUserMessage = {
        ...chatAfterUserMessage,
        conversationId: persistedConversation.id
      };
      baseChat = {
        ...baseChat,
        conversationId: persistedConversation.id
      };
      setConversations((prev) => ({
        ...prev,
        [agentId]: chatAfterUserMessage
      }));
    } catch (error) {
      console.error('Nachricht konnte nicht gespeichert werden.', error);
      window.alert('Deine Nachricht konnte nicht gespeichert werden. Bitte versuche es erneut.');
      setConversations(previousConversations);
      setPendingResponseAgentId(null);
      return;
    }

    const effectiveWebhookUrl = selectedAgent.webhookUrl?.trim() || settings.webhookUrl;
    const webhookSettings: AgentSettings = {
      ...settings,
      webhookUrl: effectiveWebhookUrl
    };

    try {
      const webhookResponse = audioRecording
        ? await (async () => {
            if (!chatAfterUserMessage.conversationId) {
              throw new Error('Konversations-ID konnte nicht bestimmt werden.');
            }
            const conversationRecordId = chatAfterUserMessage.conversationId;
            const uploadResult = await uploadAndPersistAudioMessage({
              conversationId: conversationRecordId,
              recording: {
                blob: audioRecording.blob,
                mimeType: audioRecording.mimeType,
                durationMs: audioRecording.durationMs,
                waveform: audioRecording.waveform
              }
            });

            return sendAudioWebhookNotification(
              webhookSettings,
              {
                message_id: uploadResult.messageId,
                profile_id: currentUser.id,
                conversation_id: conversationRecordId,
                storage_path: uploadResult.storagePath,
                signed_url: uploadResult.signedUrl,
                mime: uploadResult.meta.mime,
                duration_ms: uploadResult.meta.duration_ms,
                ...(uploadResult.meta.waveform ? { waveform: uploadResult.meta.waveform } : {})
              }
            );
          })()
        : await sendWebhookMessage(webhookSettings, {
            chatId: chatAfterUserMessage.id,
            message: trimmedText,
            messageId: userMessage.id,
            history: chatAfterUserMessage.messages,
            attachments: files
          });

      const responseDate = new Date();
      const agentMessage: ChatMessage = {
        id: createId(),
        author: 'agent',
        content: webhookResponse.message,
        timestamp: formatTimestamp(responseDate)
      };
      const agentPreview = toPreview(agentMessage.content || defaultPreview);
      const messagesWithAgent = [...chatAfterUserMessage.messages, agentMessage];
      const chatAfterAgent: Chat = {
        ...chatAfterUserMessage,
        messages: messagesWithAgent,
        preview: agentPreview,
        lastUpdated: formatTimestamp(responseDate)
      };

      setConversations((prev) => ({
        ...prev,
        [agentId]: chatAfterAgent
      }));

      try {
        await upsertAgentConversation(currentUser.id, agentId, {
          messages: messagesWithAgent,
          summary: agentPreview,
          lastMessageAt: responseDate.toISOString(),
          agentName: chatAfterAgent.name,
          agentDescription: selectedAgent.description ?? '',
          agentAvatarUrl: selectedAgent.avatarUrl ?? null,
          agentWebhookUrl: selectedAgent.webhookUrl ?? null,
          agentTools: selectedAgent.tools
        });
      } catch (persistError) {
        console.error('Antwort konnte nicht gespeichert werden.', persistError);
      }
    } catch (error) {
      const errorDate = new Date();
      const fallbackDescription = 'Unbekannter Fehler beim Webhook-Aufruf.';
      const errorDescription =
        error instanceof Error && error.message ? error.message : fallbackDescription;
      const agentErrorMessage: ChatMessage = {
        id: createId(),
        author: 'agent',
        content: audioRecording
          ? `Audio-Webhook Fehler: ${errorDescription}`
          : error instanceof Error
          ? `Webhook Fehler: ${errorDescription}`
          : fallbackDescription,
        timestamp: formatTimestamp(errorDate)
      };
      const errorPreview = toPreview(agentErrorMessage.content);
      const messagesWithError = [...chatAfterUserMessage.messages, agentErrorMessage];
      const chatWithError: Chat = {
        ...chatAfterUserMessage,
        messages: messagesWithError,
        preview: errorPreview,
        lastUpdated: formatTimestamp(errorDate)
      };

      setConversations((prev) => ({
        ...prev,
        [agentId]: chatWithError
      }));

      try {
        await upsertAgentConversation(currentUser.id, agentId, {
          messages: messagesWithError,
          summary: errorPreview,
          lastMessageAt: errorDate.toISOString(),
          agentName: chatWithError.name,
          agentDescription: selectedAgent.description ?? '',
          agentAvatarUrl: selectedAgent.avatarUrl ?? null,
          agentWebhookUrl: selectedAgent.webhookUrl ?? null,
          agentTools: selectedAgent.tools
        });
      } catch (persistError) {
        console.error('Fehlernachricht konnte nicht gespeichert werden.', persistError);
      }

      if (audioRecording) {
        showToast({
          type: 'error',
          title: 'Audionachricht fehlgeschlagen',
          description: errorDescription
        });
        throw error instanceof Error ? error : new Error(errorDescription);
      }
    } finally {
      setPendingResponseAgentId(null);
    }
  };

  return (
    <div className="relative flex h-[100dvh] flex-col overflow-hidden bg-[#111111] text-white">
      <div className="flex flex-1 overflow-hidden">
        {(!isWorkspaceCollapsed || isMobileWorkspaceOpen) && (
          <ChatOverviewPanel
            agents={agentOverviewItems}
            activeAgentId={selectedAgent?.id ?? null}
            onSelectAgent={handleSelectAgent}
            isMobileOpen={isMobileWorkspaceOpen}
            onCloseMobile={() => setMobileWorkspaceOpen(false)}
            onCreateAgent={handleOpenAgentCreation}
          />
        )}

        <main className="flex flex-1 min-h-0 flex-col">
          <ChatHeader
            agentName={activeAgentName}
            agentRole={activeAgentRole}
            agentStatus="online"
            onOpenOverview={() => setMobileWorkspaceOpen(true)}
            agentAvatar={activeAgentAvatar}
            userName={currentUser?.name}
            userAvatar={accountAvatar}
            onOpenProfile={() => navigate('/profile')}
            onToggleSearch={() => setSearchOpen((prev) => !prev)}
            isSearchOpen={isSearchOpen}
          />

          {isSearchOpen && (
            <div className="flex items-center gap-3 border-b border-white/10 bg-[#161616]/80 px-4 py-3 backdrop-blur-xl lg:hidden">
              <input
                className="flex-1 bg-transparent text-sm text-white placeholder:text-white/40 focus:outline-none"
                placeholder="Im Chat suchen"
                value={searchQuery}
                onChange={(event) => setSearchQuery(event.target.value)}
                autoFocus
              />
              {searchActive && (
                <span className="text-xs uppercase tracking-[0.2em] text-white/40">{searchResultCount} Treffer</span>
              )}
            </div>
          )}

          <div className="hidden items-center justify-between px-4 pt-4 md:px-6 lg:flex">
            <button
              onClick={() => setWorkspaceCollapsed((prev) => !prev)}
              className="inline-flex items-center justify-center rounded-full border border-white/10 bg-white/[0.02] p-2 text-white/60 transition hover:bg-white/10"
              aria-label={isWorkspaceCollapsed ? 'Workspace anzeigen' : 'Workspace ausblenden'}
            >
              {isWorkspaceCollapsed ? (
                <ChevronDoubleRightIcon className="h-5 w-5" />
              ) : (
                <ChevronDoubleLeftIcon className="h-5 w-5" />
              )}
            </button>
            <div className="flex items-center gap-3">
              {isSearchOpen && (
                <div className="flex items-center gap-3 rounded-full border border-white/10 bg-white/[0.05] px-4 py-2">
                  <input
                    className="w-44 bg-transparent text-sm text-white placeholder:text-white/40 focus:outline-none"
                    placeholder="Im Chat suchen"
                    value={searchQuery}
                    onChange={(event) => setSearchQuery(event.target.value)}
                    autoFocus
                  />
                  {searchActive && (
                    <span className="text-xs uppercase tracking-[0.2em] text-white/40">
                      {searchResultCount} Treffer
                    </span>
                  )}
                </div>
              )}
              <button
                onClick={() => setSearchOpen((prev) => !prev)}
                className="inline-flex items-center justify-center rounded-full border border-white/10 bg-white/[0.02] p-2 text-white/70 transition hover:bg-white/10"
                aria-label={isSearchOpen ? 'Suche schließen' : 'Suche öffnen'}
              >
                <MagnifyingGlassIcon className="h-5 w-5" />
              </button>
            </div>
          </div>

          <div className="flex flex-1 min-h-0 flex-col overflow-hidden">
            {hasAgents ? (
              <>
                {visibleChat ? (
                  <ChatTimeline
                    chat={visibleChat}
                    agentAvatar={activeAgentAvatar}
                    userAvatar={accountAvatar}
                    isAwaitingResponse={pendingResponseAgentId === visibleChat.id}
                    emptyStateMessage={searchActive ? 'Keine Nachrichten gefunden.' : undefined}
                  />
                ) : isLoadingChats ? (
                  <div className="flex flex-1 items-center justify-center px-6 text-sm text-white/60">
                    Chats werden geladen …
                  </div>
                ) : null}

                <div className="mt-auto border-t border-white/5 bg-[#111111] px-4 pb-[calc(env(safe-area-inset-bottom)+1.5rem)] pt-3 md:px-8 md:pb-10 md:pt-4">
                  <ChatInput onSendMessage={handleSendMessage} />
                  <p className="mt-3 text-center text-xs text-white/40 md:text-left">
                    Audio- und Textnachrichten werden direkt an deinen n8n-Webhook gesendet und als strukturierte Antwort im Stream angezeigt.
                  </p>
                </div>
              </>
            ) : (
              <div className="flex flex-1 flex-col items-center justify-center px-6 text-center">
                <div className="max-w-md space-y-5">
                  <h2 className="text-2xl font-semibold text-white">Baue deinen ersten Agenten</h2>
                  <p className="text-sm text-white/60">
                    Lege deinen ersten Agenten an, um deine Chats zu starten.
                  </p>
                  <button
                    type="button"
                    onClick={handleOpenAgentCreation}
                    className="inline-flex items-center justify-center rounded-full bg-gradient-to-r from-brand-gold via-brand-deep to-brand-gold px-6 py-3 text-sm font-semibold text-black shadow-glow transition hover:opacity-90"
                  >
                    Ersten Agent erstellen
                  </button>
                </div>
              </div>
            )}
          </div>
        </main>
      </div>
    </div>
  );
}
