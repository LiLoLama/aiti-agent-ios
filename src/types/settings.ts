export type AgentAuthType = 'none' | 'apiKey' | 'basic' | 'oauth';

export interface AgentSettings {
  profileName: string;
  profileRole: string;
  profileAvatarImage: string | null;
  agentAvatarImage: string | null;
  webhookUrl: string;
  authType: AgentAuthType;
  apiKey?: string;
  basicAuthUsername?: string;
  basicAuthPassword?: string;
  oauthToken?: string;
  colorScheme: 'light' | 'dark';
}

export const DEFAULT_AGENT_SETTINGS: AgentSettings = {
  profileName: 'Max Mustermann',
  profileRole: 'AI Operations Lead',
  profileAvatarImage: null,
  agentAvatarImage: null,
  webhookUrl: '',
  authType: 'none',
  colorScheme: 'dark'
};

export type AgentSettingsEventPayload = Omit<
  AgentSettings,
  'apiKey' | 'basicAuthPassword' | 'oauthToken'
>;

export const toSettingsEventPayload = (
  settings: AgentSettings
): AgentSettingsEventPayload => {
  const { apiKey: _apiKey, basicAuthPassword: _basic, oauthToken: _oauth, ...payload } = settings;
  return payload;
};
