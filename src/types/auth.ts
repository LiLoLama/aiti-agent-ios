export type UserRole = 'user' | 'admin';

export interface AgentProfile {
  id: string;
  name: string;
  description: string;
  avatarUrl: string | null;
  tools: string[];
  webhookUrl: string;
}

export interface AuthUser {
  id: string;
  name: string;
  email: string;
  role: UserRole;
  isActive: boolean;
  avatarUrl: string | null;
  emailVerified: boolean;
  agents: AgentProfile[];
  bio?: string;
  hasRemoteProfile: boolean;
}

export interface AuthCredentials {
  email: string;
  password: string;
}

export interface RegistrationPayload {
  name: string;
  email: string;
  password: string;
}

export type ProfileUpdatePayload = Partial<
  Pick<AuthUser, 'name' | 'avatarUrl' | 'bio'> & { emailVerified?: boolean }
>;

export interface AgentDraft {
  name: string;
  description: string;
  avatarUrl: string | null;
  tools: string[];
  webhookUrl: string;
}

export type AgentUpdatePayload = Partial<AgentDraft>;
