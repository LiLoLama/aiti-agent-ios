import { AgentProfile, AuthUser } from '../types/auth';

type LegacyStoredUser = AuthUser & { password?: string | null };
type StoredUser = AuthUser;

const createAgentId = () =>
  typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function'
    ? crypto.randomUUID()
    : `agent-${Math.random().toString(36).slice(2, 10)}`;

const USERS_KEY = 'aiti-auth-users';
const CURRENT_USER_KEY = 'aiti-auth-current-user';
const LEGACY_USER_IDS = new Set(['admin-001', 'user-001', 'user-002']);

const withAgentDefaults = (user: LegacyStoredUser): StoredUser => {
  const { password: _legacyPassword, ...authLike } = user;
  const agents = Array.isArray(authLike.agents)
    ? (authLike.agents as Partial<AgentProfile>[]).map((agent, index) => ({
        id: agent?.id ?? `${authLike.id}-${index}-${createAgentId()}`,
        name: agent?.name?.trim() && agent.name.length > 0 ? agent.name : `Agent ${index + 1}`,
        description: agent?.description ?? '',
        avatarUrl: agent?.avatarUrl ?? null,
        tools: Array.isArray(agent?.tools)
          ? agent.tools.map((tool) => tool.trim()).filter((tool) => tool.length > 0)
          : [],
        webhookUrl: agent?.webhookUrl ?? ''
      }))
    : [];

  return {
    ...authLike,
    agents
  };
};

const isBrowser = typeof window !== 'undefined';

const safeParse = <T>(value: string | null, fallback: T): T => {
  if (!value) {
    return fallback;
  }

  try {
    return JSON.parse(value) as T;
  } catch (error) {
    console.warn('Konnte Auth-Daten nicht laden, verwende Standardwerte.', error);
    return fallback;
  }
};

export const loadStoredUsers = (): StoredUser[] => {
  if (!isBrowser) {
    return [];
  }

  const stored = window.localStorage.getItem(USERS_KEY);
  const users = safeParse<LegacyStoredUser[]>(stored, []);
  const filteredUsers = users.filter((user) => !LEGACY_USER_IDS.has(user.id));
  const sanitizedUsers = filteredUsers.map(withAgentDefaults);

  if (stored) {
    if (sanitizedUsers.length) {
      window.localStorage.setItem(USERS_KEY, JSON.stringify(sanitizedUsers));
    } else {
      window.localStorage.removeItem(USERS_KEY);
    }
  }

  return sanitizedUsers;
};

export const saveStoredUsers = (users: LegacyStoredUser[]) => {
  if (!isBrowser) {
    return;
  }

  const sanitizedUsers = users
    .filter((user) => !LEGACY_USER_IDS.has(user.id))
    .map(withAgentDefaults);
  window.localStorage.setItem(USERS_KEY, JSON.stringify(sanitizedUsers));
};

export const loadCurrentUserId = (): string | null => {
  if (!isBrowser) {
    return null;
  }

  const stored = window.localStorage.getItem(CURRENT_USER_KEY);
  return stored ? stored : null;
};

export const saveCurrentUserId = (userId: string | null) => {
  if (!isBrowser) {
    return;
  }

  if (!userId) {
    window.localStorage.removeItem(CURRENT_USER_KEY);
    return;
  }

  window.localStorage.setItem(CURRENT_USER_KEY, userId);
};

export const toAuthUser = (user: StoredUser): AuthUser => ({ ...user });

export type { StoredUser };
