declare global {
  interface WindowEventMap {
    'aiti-settings-update': CustomEvent<import('./settings').AgentSettingsEventPayload>;
  }
}

export {};
