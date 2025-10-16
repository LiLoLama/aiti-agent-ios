import { AgentAuthType, AgentSettings } from '../types/settings';

export interface IntegrationSecretRecord {
  id: string;
  profile_id: string;
  webhook_url: string | null;
  auth_type: string | null;
  api_key: string | null;
  basic_username: string | null;
  basic_password: string | null;
  oauth_token: string | null;
  created_at?: string | null;
  updated_at?: string | null;
}

const STORAGE_PREFIX = 'aiti-integration-secret:';

const generateId = () => {
  if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') {
    return crypto.randomUUID();
  }

  const segments = Array.from({ length: 5 }, () => Math.random().toString(16).slice(2, 10));
  return `${segments[0]}-${segments[1].slice(0, 4)}-${segments[2].slice(0, 4)}-${segments[3].slice(0, 4)}-${segments[4]}${Math.random()
    .toString(16)
    .slice(2, 10)}`.slice(0, 36);
};

const storageKey = (profileId: string) => `${STORAGE_PREFIX}${profileId}`;

const isAgentAuthType = (value: unknown): value is AgentAuthType =>
  value === 'none' || value === 'apiKey' || value === 'basic' || value === 'oauth';

const readRecord = (profileId: string): IntegrationSecretRecord | null => {
  if (typeof window === 'undefined') {
    return null;
  }

  const raw = window.localStorage.getItem(storageKey(profileId));
  if (!raw) {
    return null;
  }

  try {
    const parsed = JSON.parse(raw) as IntegrationSecretRecord;
    if (!parsed || typeof parsed !== 'object') {
      return null;
    }

    return {
      id: typeof parsed.id === 'string' ? parsed.id : generateId(),
      profile_id: profileId,
      webhook_url: typeof parsed.webhook_url === 'string' ? parsed.webhook_url : null,
      auth_type: typeof parsed.auth_type === 'string' ? parsed.auth_type : 'none',
      api_key: typeof parsed.api_key === 'string' ? parsed.api_key : null,
      basic_username: typeof parsed.basic_username === 'string' ? parsed.basic_username : null,
      basic_password: typeof parsed.basic_password === 'string' ? parsed.basic_password : null,
      oauth_token: typeof parsed.oauth_token === 'string' ? parsed.oauth_token : null,
      created_at: typeof parsed.created_at === 'string' ? parsed.created_at : null,
      updated_at: typeof parsed.updated_at === 'string' ? parsed.updated_at : null
    };
  } catch (error) {
    console.error('Integrations-Secrets konnten nicht gelesen werden.', error);
    return null;
  }
};

export async function fetchIntegrationSecret(profileId: string): Promise<IntegrationSecretRecord | null> {
  return readRecord(profileId);
}

export const applyIntegrationSecretToSettings = (
  settings: AgentSettings,
  record: IntegrationSecretRecord | null
): AgentSettings => {
  if (!record) {
    return {
      ...settings,
      webhookUrl: settings.webhookUrl ?? '',
      authType: settings.authType ?? 'none',
      apiKey: undefined,
      basicAuthUsername: undefined,
      basicAuthPassword: undefined,
      oauthToken: undefined
    };
  }

  const authType = isAgentAuthType(record.auth_type) ? record.auth_type : 'none';

  return {
    ...settings,
    webhookUrl: record.webhook_url?.trim() ?? '',
    authType,
    apiKey: authType === 'apiKey' ? record.api_key ?? undefined : undefined,
    basicAuthUsername: authType === 'basic' ? record.basic_username ?? undefined : undefined,
    basicAuthPassword: authType === 'basic' ? record.basic_password ?? undefined : undefined,
    oauthToken: authType === 'oauth' ? record.oauth_token ?? undefined : undefined
  };
};

export interface UpsertIntegrationSecretPayload {
  profileId: string;
  webhookUrl: string;
  authType: AgentAuthType;
  apiKey?: string | null;
  basicAuthUsername?: string | null;
  basicAuthPassword?: string | null;
  oauthToken?: string | null;
}

export async function upsertIntegrationSecret(
  payload: UpsertIntegrationSecretPayload
): Promise<IntegrationSecretRecord> {
  const timestamp = new Date().toISOString();
  const existing = readRecord(payload.profileId);
  const record: IntegrationSecretRecord = {
    id: existing?.id ?? generateId(),
    profile_id: payload.profileId,
    webhook_url: payload.webhookUrl,
    auth_type: payload.authType,
    api_key: payload.authType === 'apiKey' ? payload.apiKey ?? null : null,
    basic_username: payload.authType === 'basic' ? payload.basicAuthUsername ?? null : null,
    basic_password: payload.authType === 'basic' ? payload.basicAuthPassword ?? null : null,
    oauth_token: payload.authType === 'oauth' ? payload.oauthToken ?? null : null,
    created_at: existing?.created_at ?? timestamp,
    updated_at: timestamp
  };

  if (typeof window !== 'undefined') {
    window.localStorage.setItem(storageKey(payload.profileId), JSON.stringify(record));
  }

  return record;
}
