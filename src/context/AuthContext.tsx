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
import { User } from '@supabase/supabase-js';
import supabase from '../utils/supabase';
import { loadCachedAuthUser, saveCachedAuthUser } from '../utils/storage';
import {
  AgentDraft,
  AgentProfile,
  AgentUpdatePayload,
  AuthCredentials,
  AuthUser,
  ProfileUpdatePayload,
  RegistrationPayload
} from '../types/auth';
import {
  deleteAgentConversation,
  fetchAgentConversations,
  mapConversationToAgentProfile,
  upsertAgentConversation
} from '../services/chatService';

interface AuthContextValue {
  currentUser: AuthUser | null;
  users: AuthUser[];
  isLoading: boolean;
  login: (credentials: AuthCredentials) => Promise<void>;
  register: (payload: RegistrationPayload) => Promise<{ sessionExists: boolean }>;
  logout: () => Promise<void>;
  updateProfile: (updates: ProfileUpdatePayload) => Promise<void>;
  toggleUserActive: (userId: string, nextActive: boolean) => Promise<void>;
  addAgent: (agent: AgentDraft) => Promise<void>;
  updateAgent: (agentId: string, updates: AgentUpdatePayload) => Promise<void>;
  removeAgent: (agentId: string) => Promise<void>;
}

interface ProfileRow {
  id: string;
  email: string | null;
  display_name: string | null;
  avatar_url: string | null;
  role: string | null;
  bio: string | null;
  email_verified: string | null;
  is_active: boolean | null;
  name: string | null;
}

type AgentMetadataRow = {
  profile_id: string;
  agent_id: string;
  agent_name: string | null;
  agent_description: string | null;
  agent_avatar_url: string | null;
  agent_webhook_url: string | null;
  agent_tools: unknown;
};

const AuthContext = createContext<AuthContextValue | undefined>(undefined);

const isRowLevelSecurityError = (error: { message?: string | null; code?: string | null } | null | undefined) => {
  if (!error) {
    return false;
  }

  const code = typeof error.code === 'string' ? error.code : '';
  const message = typeof error.message === 'string' ? error.message : '';
  return code === '42501' || message.toLowerCase().includes('row-level security');
};

const normalizeBooleanText = (value: string | null | undefined, fallback = false) => {
  if (typeof value !== 'string') {
    return fallback;
  }

  switch (value.trim().toLowerCase()) {
    case 'true':
    case 't':
    case '1':
    case 'yes':
    case 'y':
      return true;
    case 'false':
    case 'f':
    case '0':
    case 'no':
    case 'n':
      return false;
    default:
      return fallback;
  }
};

const normalizeTools = (tools: string[] | null | undefined): string[] => {
  if (!Array.isArray(tools)) {
    return [];
  }

  const normalized = tools
    .map((tool) => tool.trim())
    .filter((tool) => tool.length > 0);

  return Array.from(new Set(normalized));
};

const createAuthUserFromSupabaseUser = (user: User, agents: AgentProfile[]): AuthUser => {
  const metadataName = typeof user.user_metadata?.name === 'string' ? user.user_metadata.name : undefined;
  const normalizedName = metadataName && metadataName.trim().length > 0 ? metadataName.trim() : user.email ?? 'Neuer Nutzer';
  const metadataAvatar =
    typeof user.user_metadata?.avatar_url === 'string' && user.user_metadata.avatar_url.trim().length > 0
      ? user.user_metadata.avatar_url
      : null;

  return {
    id: user.id,
    name: normalizedName,
    email: user.email ?? '',
    role: 'user',
    isActive: true,
    avatarUrl: metadataAvatar,
    emailVerified: Boolean(user.email_confirmed_at),
    agents,
    bio: '',
    hasRemoteProfile: false
  };
};

const mapProfileRowToAuthUser = (
  row: ProfileRow,
  agents: AgentProfile[],
  fallback?: {
    name?: string | null;
    email?: string | null;
    avatarUrl?: string | null;
    emailVerified?: boolean;
  }
): AuthUser => {
  const normalizedDisplayName = row.display_name?.trim().length ? row.display_name.trim() : null;
  const normalizedEmail = row.email?.trim().length ? row.email.trim() : null;
  const fallbackNameTrimmed = fallback?.name?.trim();
  const fallbackEmailTrimmed = fallback?.email?.trim();
  const fallbackName = fallbackNameTrimmed && fallbackNameTrimmed.length > 0 ? fallbackNameTrimmed : null;
  const fallbackEmail = fallbackEmailTrimmed && fallbackEmailTrimmed.length > 0 ? fallbackEmailTrimmed : null;
  const fallbackAvatar = fallback?.avatarUrl ?? null;
  const fallbackEmailVerified = fallback?.emailVerified ?? false;

  return {
    id: row.id,
    name: normalizedDisplayName ?? fallbackName ?? fallbackEmail ?? 'Neuer Nutzer',
    email: normalizedEmail ?? fallbackEmail ?? '',
    role: row.role === 'admin' ? 'admin' : 'user',
    isActive: row.is_active ?? true,
    avatarUrl: row.avatar_url ?? fallbackAvatar,
    emailVerified: normalizeBooleanText(row.email_verified, fallbackEmailVerified),
    agents,
    bio: row.bio ?? undefined,
    hasRemoteProfile: true
  };
};

const mapAgentMetadataRow = (row: AgentMetadataRow): AgentProfile => ({
  id: row.agent_id,
  name: row.agent_name?.trim().length ? row.agent_name.trim() : 'AITI Agent',
  description: row.agent_description ?? '',
  avatarUrl: row.agent_avatar_url ?? null,
  tools: normalizeTools(Array.isArray(row.agent_tools) ? (row.agent_tools as string[]) : null),
  webhookUrl: row.agent_webhook_url ?? ''
});

const generateId = () => {
  if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') {
    return crypto.randomUUID();
  }

  const randomSegment = () => Math.random().toString(16).slice(2, 10).padEnd(8, '0');
  return `${randomSegment()}-${randomSegment().slice(0, 4)}-${randomSegment().slice(0, 4)}-${randomSegment().slice(0, 4)}-${randomSegment()}${randomSegment()}`.slice(
    0,
    36
  );
};

const sanitizeAgentDraft = (id: string, agent: AgentDraft): AgentProfile => ({
  id,
  name: agent.name.trim().length > 0 ? agent.name.trim() : 'Unbenannter Agent',
  description: agent.description?.trim() ?? '',
  avatarUrl: agent.avatarUrl ?? null,
  tools: normalizeTools(agent.tools),
  webhookUrl: agent.webhookUrl?.trim() ?? ''
});

const sanitizeAgentUpdate = (existing: AgentProfile, updates: AgentUpdatePayload): AgentProfile => ({
  ...existing,
  name: updates.name?.trim()?.length ? updates.name.trim() : existing.name,
  description: updates.description?.trim() ?? existing.description,
  avatarUrl: updates.avatarUrl ?? existing.avatarUrl,
  tools: updates.tools ? normalizeTools(updates.tools) : existing.tools,
  webhookUrl: updates.webhookUrl?.trim() ?? existing.webhookUrl
});

const ensureProfileForUser = async (user: User, preferredName?: string) => {
  const { data: existing, error: selectError } = await supabase
    .from('profiles')
    .select('id')
    .eq('id', user.id)
    .maybeSingle();

  if (selectError && !isRowLevelSecurityError(selectError)) {
    throw new Error(`Profil konnte nicht geladen werden: ${selectError.message}`);
  }

  if (existing) {
    return existing;
  }

  if (selectError && isRowLevelSecurityError(selectError)) {
    console.warn('Profil konnte nicht geprüft werden, Zugriff wurde durch RLS verweigert.', selectError);
    return null;
  }

  const metadataName = typeof user.user_metadata?.name === 'string' ? user.user_metadata.name : undefined;
  const normalizedName =
    preferredName?.trim()?.length
      ? preferredName.trim()
      : metadataName && metadataName.trim().length > 0
      ? metadataName.trim()
      : user.email?.split('@')[0] ?? 'Neuer Nutzer';

  const avatar =
    typeof user.user_metadata?.avatar_url === 'string' && user.user_metadata.avatar_url.trim().length > 0
      ? user.user_metadata.avatar_url
      : null;

  const { error: insertError } = await supabase.from('profiles').insert({
    id: user.id,
    email: user.email ?? '',
    display_name: normalizedName,
    avatar_url: avatar,
    role: 'user',
    bio: '',
    email_verified: user.email_confirmed_at ? 'true' : 'false',
    is_active: true
  });

  if (insertError) {
    if (isRowLevelSecurityError(insertError)) {
      console.warn('Profil konnte nicht gespeichert werden: Zugriff durch RLS verweigert.', insertError);
      return null;
    }

    throw new Error(`Profil konnte nicht gespeichert werden: ${insertError.message}`);
  }

  return { id: user.id };
};

export function AuthProvider({ children }: { children: ReactNode }) {
  const cachedUserRef = useRef<AuthUser | null>(loadCachedAuthUser());
  const [currentUser, setCurrentUserState] = useState<AuthUser | null>(cachedUserRef.current);
  const [users, setUsers] = useState<AuthUser[]>(() => (cachedUserRef.current ? [cachedUserRef.current] : []));
  const [isLoading, setIsLoading] = useState<boolean>(true);

  const currentUserRef = useRef<AuthUser | null>(cachedUserRef.current);
  const currentUserLoaderRef = useRef<Promise<void> | null>(null);

  const setCurrentUser = useCallback((nextUser: AuthUser | null) => {
    currentUserRef.current = nextUser;
    setCurrentUserState(nextUser);
    cachedUserRef.current = nextUser;
    saveCachedAuthUser(nextUser);
  }, []);

  const refreshUsersList = useCallback(
    async (currentCandidate: AuthUser | null = currentUserRef.current) => {
      try {
        const { data: profileRows, error: profilesError } = await supabase
          .from('profiles')
          .select('id, email, display_name, avatar_url, role, bio, email_verified, is_active, name');

        if (profilesError) {
          if (isRowLevelSecurityError(profilesError)) {
            setUsers(currentCandidate ? [currentCandidate] : []);
            return currentCandidate ? [currentCandidate] : [];
          }

          throw new Error(profilesError.message);
        }

        const { data: agentRows, error: agentsError } = await supabase
          .from('agent_conversations')
          .select('profile_id, agent_id, agent_name, agent_description, agent_avatar_url, agent_webhook_url, agent_tools');

        if (agentsError) {
          if (isRowLevelSecurityError(agentsError)) {
            const fallbackUsers = (profileRows ?? []).map((row) =>
              mapProfileRowToAuthUser(row as ProfileRow, [], {
                name: row.display_name ?? undefined,
                email: row.email ?? undefined,
                avatarUrl: row.avatar_url ?? undefined
              })
            );
            setUsers(fallbackUsers);
            return fallbackUsers;
          }

          throw new Error(agentsError.message);
        }

        const agentsByProfile = new Map<string, AgentProfile[]>();
        (agentRows ?? []).forEach((row) => {
          const agent = mapAgentMetadataRow(row as AgentMetadataRow);
          const list = agentsByProfile.get(row.profile_id) ?? [];
          list.push(agent);
          agentsByProfile.set(row.profile_id, list);
        });

        const nextUsers = (profileRows ?? []).map((row) =>
          mapProfileRowToAuthUser(row as ProfileRow, agentsByProfile.get(row.id) ?? [], {
            name: row.display_name ?? undefined,
            email: row.email ?? undefined,
            avatarUrl: row.avatar_url ?? undefined
          })
        );

        setUsers(nextUsers);
        return nextUsers;
      } catch (error) {
        console.error('Nutzerliste konnte nicht geladen werden.', error);
        const fallback = currentCandidate ? [currentCandidate] : [];
        setUsers(fallback);
        return fallback;
      }
    },
    []
  );

  const loadCurrentUser = useCallback(async () => {
    if (currentUserLoaderRef.current) {
      return currentUserLoaderRef.current;
    }

    const loadPromise = (async () => {
      setIsLoading(true);

      try {
        const {
          data: { session }
        } = await supabase.auth.getSession();

        const sessionUser = session?.user ?? null;

        if (!sessionUser) {
          setCurrentUser(null);
          setUsers([]);
          return;
        }

        await ensureProfileForUser(sessionUser).catch((error) => {
          console.warn('Profil konnte nicht automatisch erstellt werden.', error);
        });

        const { data: profileRow, error: profileError } = await supabase
          .from('profiles')
          .select('id, email, display_name, avatar_url, role, bio, email_verified, is_active, name')
          .eq('id', sessionUser.id)
          .maybeSingle();

        if (profileError && !isRowLevelSecurityError(profileError)) {
          throw new Error(profileError.message);
        }

        let agents: AgentProfile[] = [];
        try {
          const records = await fetchAgentConversations(sessionUser.id);
          agents = records.map((record) => mapConversationToAgentProfile(record, 'AITI Agent'));
        } catch (error) {
          console.error('Agenten konnten nicht geladen werden.', error);
        }

        const mappedCurrent = profileRow
          ? mapProfileRowToAuthUser(profileRow as ProfileRow, agents, {
              name:
                typeof sessionUser.user_metadata?.name === 'string'
                  ? sessionUser.user_metadata.name
                  : sessionUser.email,
              email: sessionUser.email,
              avatarUrl:
                typeof sessionUser.user_metadata?.avatar_url === 'string'
                  ? sessionUser.user_metadata.avatar_url
                  : null,
              emailVerified: Boolean(sessionUser.email_confirmed_at)
            })
          : createAuthUserFromSupabaseUser(sessionUser, agents);

        setCurrentUser(mappedCurrent);
        await refreshUsersList(mappedCurrent);
      } catch (error) {
        console.error('Authentifizierungsstatus konnte nicht geladen werden.', error);
        setCurrentUser(null);
        setUsers([]);
      } finally {
        setIsLoading(false);
      }
    })();

    currentUserLoaderRef.current = loadPromise;

    try {
      await loadPromise;
    } finally {
      currentUserLoaderRef.current = null;
    }
  }, [refreshUsersList, setCurrentUser]);

  useEffect(() => {
    let isMounted = true;

    const initialize = async () => {
      if (!isMounted) {
        return;
      }

      await loadCurrentUser();
    };

    void initialize();

    const { data: authListener } = supabase.auth.onAuthStateChange(() => {
      if (!isMounted) {
        return;
      }

      void loadCurrentUser();
    });

    return () => {
      isMounted = false;
      authListener.subscription?.unsubscribe();
    };
  }, [loadCurrentUser]);

  const login = useCallback(async ({ email, password }: AuthCredentials) => {
    const { data, error } = await supabase.auth.signInWithPassword({ email, password });

    if (error) {
      throw new Error(error.message ?? 'Ungültige Anmeldedaten.');
    }

    if (data.user) {
      await ensureProfileForUser(data.user).catch((creationError) => {
        console.warn('Profil konnte nach dem Login nicht erstellt werden.', creationError);
      });
    }

    await loadCurrentUser();
  }, [loadCurrentUser]);

  const register = useCallback(
    async ({ name, email, password }: RegistrationPayload) => {
      const { data, error } = await supabase.auth.signUp({
        email,
        password,
        options: {
          data: {
            name
          }
        }
      });

      if (error) {
        throw new Error(error.message ?? 'Registrierung fehlgeschlagen.');
      }

      const sessionExists = Boolean(data.session);

      if (sessionExists && data.user) {
        await ensureProfileForUser(data.user, name).catch((creationError) => {
          console.warn('Profil konnte nach der Registrierung nicht erstellt werden.', creationError);
        });
        await loadCurrentUser();
      }

      return { sessionExists };
    },
    [loadCurrentUser]
  );

  const logout = useCallback(async () => {
    const { error } = await supabase.auth.signOut();
    if (error) {
      throw new Error(error.message ?? 'Abmeldung fehlgeschlagen.');
    }

    setCurrentUser(null);
    setUsers([]);
  }, []);

  const updateProfile = useCallback(
    async (updates: ProfileUpdatePayload) => {
      if (!currentUser) {
        throw new Error('Kein aktiver Nutzer gefunden.');
      }

      const payload: Record<string, unknown> = { updated_at: new Date().toISOString() };

      if (typeof updates.name === 'string') {
        const trimmed = updates.name.trim();
        payload.display_name = trimmed.length > 0 ? trimmed : currentUser.name;
      }

      if ('avatarUrl' in updates) {
        payload.avatar_url = updates.avatarUrl ?? null;
      }

      if ('bio' in updates) {
        payload.bio = updates.bio ?? '';
      }

      if ('emailVerified' in updates) {
        payload.email_verified = updates.emailVerified ? 'true' : 'false';
      }

      const { error } = await supabase.from('profiles').update(payload).eq('id', currentUser.id);

      if (error) {
        throw new Error(error.message ?? 'Profil konnte nicht aktualisiert werden.');
      }

      await loadCurrentUser();
    },
    [currentUser, loadCurrentUser]
  );

  const toggleUserActive = useCallback(
    async (userId: string, nextActive: boolean) => {
      const { error } = await supabase
        .from('profiles')
        .update({ is_active: nextActive, updated_at: new Date().toISOString() })
        .eq('id', userId);

      if (error) {
        throw new Error(error.message ?? 'Nutzerstatus konnte nicht aktualisiert werden.');
      }

      if (currentUser?.id === userId) {
        await loadCurrentUser();
      } else {
        await refreshUsersList();
      }
    },
    [currentUser?.id, loadCurrentUser, refreshUsersList]
  );

  const addAgent = useCallback(
    async (agent: AgentDraft) => {
      if (!currentUser) {
        throw new Error('Kein aktiver Nutzer gefunden.');
      }

      const sanitized = sanitizeAgentDraft(generateId(), agent);

      await upsertAgentConversation(currentUser.id, sanitized.id, {
        agentName: sanitized.name,
        agentDescription: sanitized.description,
        agentAvatarUrl: sanitized.avatarUrl,
        agentWebhookUrl: sanitized.webhookUrl,
        agentTools: sanitized.tools,
        messages: [],
        summary: null,
        lastMessageAt: null
      });

      await loadCurrentUser();
    },
    [currentUser, loadCurrentUser]
  );

  const updateAgent = useCallback(
    async (agentId: string, updates: AgentUpdatePayload) => {
      if (!currentUser) {
        throw new Error('Kein aktiver Nutzer gefunden.');
      }

      const existing = currentUser.agents.find((agent) => agent.id === agentId);

      if (!existing) {
        throw new Error('Agent wurde nicht gefunden.');
      }

      const sanitized = sanitizeAgentUpdate(existing, updates);

      await upsertAgentConversation(currentUser.id, agentId, {
        agentName: sanitized.name,
        agentDescription: sanitized.description,
        agentAvatarUrl: sanitized.avatarUrl,
        agentWebhookUrl: sanitized.webhookUrl,
        agentTools: sanitized.tools
      });

      await loadCurrentUser();
    },
    [currentUser, loadCurrentUser]
  );

  const removeAgent = useCallback(
    async (agentId: string) => {
      if (!currentUser) {
        throw new Error('Kein aktiver Nutzer gefunden.');
      }

      await deleteAgentConversation(currentUser.id, agentId);
      await loadCurrentUser();
    },
    [currentUser, loadCurrentUser]
  );

  const value = useMemo<AuthContextValue>(
    () => ({
      currentUser,
      users,
      isLoading,
      login,
      register,
      logout,
      updateProfile,
      toggleUserActive,
      addAgent,
      updateAgent,
      removeAgent
    }),
    [addAgent, currentUser, isLoading, login, logout, register, removeAgent, toggleUserActive, updateAgent, updateProfile, users]
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth muss innerhalb eines AuthProvider verwendet werden.');
  }

  return context;
};
