export type ChatAttachment = {
  id: string;
  name: string;
  size: number;
  type: string;
  url: string;
  kind: 'file' | 'audio';
  durationSeconds?: number;
};

export type ChatMessage = {
  id: string;
  author: 'agent' | 'user';
  content: string;
  timestamp: string;
  attachments?: ChatAttachment[];
};

export type Chat = {
  id: string;
  conversationId: string | null;
  name: string;
  folder?: string;
  folderId?: string;
  lastUpdated: string;
  preview: string;
  messages: ChatMessage[];
};

export const sampleChats: Chat[] = [];
