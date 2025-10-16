import { FormEvent, useCallback, useEffect, useRef, useState, type ChangeEvent } from 'react';
import { useNavigate } from 'react-router-dom';
import { ArrowLeftIcon } from '@heroicons/react/24/outline';
import clsx from 'clsx';

import agentAvatar from '../assets/agent-avatar.png';
import userAvatar from '../assets/default-user.svg';
import { AgentAuthType, AgentSettings, toSettingsEventPayload } from '../types/settings';
import { loadAgentSettings, saveAgentSettings } from '../utils/storage';
import { applyColorScheme } from '../utils/theme';
import { sendWebhookMessage } from '../utils/webhook';
import { prepareImageForStorage } from '../utils/image';
import { useAuth } from '../context/AuthContext';
import {
  applyIntegrationSecretToSettings,
  fetchIntegrationSecret,
  upsertIntegrationSecret
} from '../services/integrationSecretsService';

export function SettingsPage() {
  const navigate = useNavigate();
  const { currentUser } = useAuth();
  const [settings, setSettings] = useState<AgentSettings>(() => loadAgentSettings());
  const profileAvatarInputRef = useRef<HTMLInputElement | null>(null);
  const agentAvatarInputRef = useRef<HTMLInputElement | null>(null);
  const [saveStatus, setSaveStatus] = useState<'idle' | 'success' | 'error'>('idle');
  const [webhookTestStatus, setWebhookTestStatus] = useState<
    'idle' | 'pending' | 'success' | 'error'
  >('idle');
  const [webhookTestMessage, setWebhookTestMessage] = useState('');
  const [isSyncingSecrets, setIsSyncingSecrets] = useState(false);

  const profileAvatarPreview = settings.profileAvatarImage ?? userAvatar;
  const agentAvatarPreview = settings.agentAvatarImage ?? agentAvatar;

  const updateSetting = <Key extends keyof AgentSettings>(
    key: Key,
    value: AgentSettings[Key]
  ) => {
    setSettings((prev) => ({
      ...prev,
      [key]: value
    }));
  };

  const handleProfileAvatarUpload = async (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file) {
      return;
    }

    try {
      const result = await prepareImageForStorage(file, {
        maxDimension: 512,
        mimeType: 'image/jpeg',
        quality: 0.9
      });

      updateSetting('profileAvatarImage', result);
    } catch (error) {
      console.error('Profilbild konnte nicht verarbeitet werden.', error);
    } finally {
      if (profileAvatarInputRef.current) {
        profileAvatarInputRef.current.value = '';
      }
    }
  };

  const handleProfileAvatarReset = () => {
    updateSetting('profileAvatarImage', null);
    if (profileAvatarInputRef.current) {
      profileAvatarInputRef.current.value = '';
    }
  };

  const handleAgentAvatarUpload = async (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file) {
      return;
    }

    try {
      const result = await prepareImageForStorage(file, {
        maxDimension: 512,
        mimeType: 'image/jpeg',
        quality: 0.9
      });

      updateSetting('agentAvatarImage', result);
    } catch (error) {
      console.error('Agentenbild konnte nicht verarbeitet werden.', error);
    } finally {
      if (agentAvatarInputRef.current) {
        agentAvatarInputRef.current.value = '';
      }
    }
  };

  const handleAgentAvatarReset = () => {
    updateSetting('agentAvatarImage', null);
    if (agentAvatarInputRef.current) {
      agentAvatarInputRef.current.value = '';
    }
  };

  useEffect(() => {
    applyColorScheme(settings.colorScheme);
  }, [settings.colorScheme]);

  const hydrateSecrets = useCallback(async () => {
    if (!currentUser?.id) {
      return;
    }

    setIsSyncingSecrets(true);

    try {
      const record = await fetchIntegrationSecret(currentUser.id);
      setSettings((prev) => applyIntegrationSecretToSettings(prev, record));
    } catch (error) {
      console.error('Integrations-Secrets konnten nicht geladen werden.', error);
    } finally {
      setIsSyncingSecrets(false);
    }
  }, [currentUser?.id]);

  useEffect(() => {
    void hydrateSecrets();
  }, [hydrateSecrets]);

  const handleSaveSettings = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!currentUser?.id) {
      setSaveStatus('error');
      setTimeout(() => setSaveStatus('idle'), 4000);
      return;
    }

    setSaveStatus('idle');
    const payload: AgentSettings = {
      ...settings,
      profileAvatarImage: settings.profileAvatarImage ?? null,
      agentAvatarImage: settings.agentAvatarImage ?? null
    };

    try {
      const sanitized: AgentSettings = {
        ...payload,
        webhookUrl: payload.webhookUrl.trim(),
        apiKey: payload.apiKey?.trim() || undefined,
        basicAuthUsername: payload.basicAuthUsername?.trim() || undefined,
        basicAuthPassword: payload.basicAuthPassword?.trim() || undefined,
        oauthToken: payload.oauthToken?.trim() || undefined
      };

      await upsertIntegrationSecret({
        profileId: currentUser.id,
        webhookUrl: sanitized.webhookUrl,
        authType: sanitized.authType,
        apiKey: sanitized.authType === 'apiKey' ? sanitized.apiKey ?? null : null,
        basicAuthUsername: sanitized.authType === 'basic' ? sanitized.basicAuthUsername ?? null : null,
        basicAuthPassword: sanitized.authType === 'basic' ? sanitized.basicAuthPassword ?? null : null,
        oauthToken: sanitized.authType === 'oauth' ? sanitized.oauthToken ?? null : null
      });

      saveAgentSettings(sanitized);
      setSettings(sanitized);
      const eventPayload = toSettingsEventPayload(sanitized);
      window.dispatchEvent(
        new CustomEvent('aiti-settings-update', {
          detail: eventPayload
        })
      );
      setSaveStatus('success');
      setTimeout(() => setSaveStatus('idle'), 4000);
    } catch (error) {
      console.error(error);
      setSaveStatus('error');
      setTimeout(() => setSaveStatus('idle'), 4000);
    }
  };

  const handleWebhookTest = async () => {
    if (webhookTestStatus === 'pending') {
      return;
    }

    if (!settings.webhookUrl?.trim()) {
      setWebhookTestStatus('error');
      setWebhookTestMessage('Bitte hinterlege zuerst eine Webhook URL.');
      return;
    }

    setWebhookTestStatus('pending');
    setWebhookTestMessage('Webhook Test läuft …');

    try {
      const timestamp = new Date();
      const messageId =
        typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function'
          ? crypto.randomUUID()
          : Math.random().toString(36).slice(2);
      const chatId =
        typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function'
          ? crypto.randomUUID()
          : `webhook-test-${Math.random().toString(36).slice(2)}`;
      const response = await sendWebhookMessage(
        settings,
        {
          chatId,
          messageId,
          message: 'Webhook Test',
          history: [
            {
              id: messageId,
              author: 'user',
              content: 'Webhook Test',
              timestamp: timestamp.toISOString()
            }
          ],
          attachments: []
        }
      );

      const trimmedResponse = response.message.trim();
      const preview =
        trimmedResponse.length > 200 ? `${trimmedResponse.slice(0, 197)}…` : trimmedResponse;
      const successMessage = trimmedResponse
        ? `Webhook Test erfolgreich. Antwort: ${preview}`
        : 'Webhook Test erfolgreich. Es wurde eine leere Antwort zurückgegeben.';

      setWebhookTestStatus('success');
      setWebhookTestMessage(successMessage);
    } catch (error) {
      setWebhookTestStatus('error');
      setWebhookTestMessage(
        error instanceof Error
          ? `Webhook Test fehlgeschlagen: ${error.message}`
          : 'Webhook Test fehlgeschlagen. Unbekannter Fehler.'
      );
    }
  };

  return (
    <div className="min-h-screen bg-[#101010] text-white">
      <div className="mx-auto max-w-6xl px-4 py-8 lg:px-12">
        <button
          onClick={() => navigate(-1)}
          className="mb-8 inline-flex items-center gap-2 rounded-full border border-white/10 px-4 py-2 text-sm text-white/60 hover:bg-white/10"
        >
          <ArrowLeftIcon className="h-5 w-5" />
          Zurück zum Chat
        </button>

        <header className="flex flex-col gap-6 rounded-3xl border border-white/10 bg-[#161616]/80 p-8 shadow-[0_0_80px_rgba(250,207,57,0.08)] backdrop-blur-xl md:flex-row md:items-center md:justify-between">
          <div>
            <p className="text-xs uppercase tracking-[0.28em] text-white/40">Workspace</p>
            <h1 className="mt-2 text-3xl font-semibold text-white">Einstellungen &amp; Personalisierung</h1>
          </div>
          <div className="flex items-center gap-4 rounded-2xl border border-white/10 bg-white/5 p-4">
            <div className="h-16 w-16 overflow-hidden rounded-2xl border border-white/10 shadow-lg">
              <img src={agentAvatar} alt="Agent" className="h-full w-full object-cover" />
            </div>
            <div>
              <h2 className="text-lg font-semibold">AITI Agent</h2>
              <p className="text-sm text-white/50">Aktiver Workflow Companion</p>
            </div>
          </div>
        </header>

        {(saveStatus !== 'idle' || isSyncingSecrets) && (
          <div
            role="status"
            className="mt-6 rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-white/80"
          >
            {isSyncingSecrets
              ? 'Lade Integrations-Einstellungen …'
              : saveStatus === 'success'
              ? 'Einstellungen wurden erfolgreich gespeichert.'
              : 'Einstellungen konnten nicht gespeichert werden. Bitte versuche es erneut.'}
          </div>
        )}

        <form onSubmit={handleSaveSettings} className="mt-10 grid gap-8 lg:grid-cols-5">
          <section className="lg:col-span-3 space-y-8">
            <div className="rounded-3xl border border-white/10 bg-[#161616]/70 p-8 shadow-2xl">
              <h3 className="text-xl font-semibold text-white">Benutzerprofil</h3>
              <div className="mt-6 flex flex-col gap-6 md:flex-row md:items-center">
                <div className="flex flex-col items-center gap-3">
                  <div className="h-24 w-24 overflow-hidden rounded-3xl border border-white/10 shadow-lg">
                    <img src={profileAvatarPreview} alt="User Avatar" className="h-full w-full object-cover" />
                  </div>
                  <button
                    type="button"
                    onClick={() => profileAvatarInputRef.current?.click()}
                    className="inline-flex items-center justify-center rounded-full bg-gradient-to-r from-brand-gold via-brand-deep to-brand-gold px-4 py-2 text-xs font-semibold uppercase tracking-[0.3em] text-surface-base shadow-glow"
                  >
                    Neu hochladen
                  </button>
                  <button
                    type="button"
                    onClick={handleProfileAvatarReset}
                    className="text-xs text-white/50 hover:text-white/80"
                  >
                    Zurücksetzen
                  </button>
                  <input
                    ref={profileAvatarInputRef}
                    type="file"
                    accept="image/*"
                    onChange={handleProfileAvatarUpload}
                    className="hidden"
                  />
                </div>
                <div className="flex-1 space-y-4">
                  <div>
                    <label className="text-xs uppercase tracking-[0.3em] text-white/40">Name</label>
                    <input
                      className="mt-2 w-full rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-white placeholder:text-white/40 focus:border-brand-gold/60 focus:outline-none"
                      placeholder="Max Mustermann"
                      value={settings.profileName}
                      onChange={(event) => updateSetting('profileName', event.target.value)}
                    />
                  </div>
                  <div>
                    <label className="text-xs uppercase tracking-[0.3em] text-white/40">Rolle</label>
                    <input
                      className="mt-2 w-full rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-white placeholder:text-white/40 focus:border-brand-gold/60 focus:outline-none"
                      placeholder="AI Operations Lead"
                      value={settings.profileRole}
                      onChange={(event) => updateSetting('profileRole', event.target.value)}
                    />
                  </div>
                </div>
              </div>
            </div>

            <div className="rounded-3xl border border-white/10 bg-[#161616]/70 p-8 shadow-2xl">
              <div className="flex items-center justify-between">
                <div>
                  <h3 className="text-xl font-semibold text-white">Webhook &amp; Integrationen</h3>
                </div>
                <button
                  type="button"
                  onClick={handleWebhookTest}
                  disabled={webhookTestStatus === 'pending'}
                  className={clsx(
                    'rounded-full border px-4 py-2 text-xs font-semibold uppercase tracking-[0.3em] transition',
                    webhookTestStatus === 'pending'
                      ? 'cursor-not-allowed border-white/20 text-white/40'
                      : 'border-brand-gold/40 text-brand-gold hover:bg-brand-gold/10'
                  )}
                >
                  {webhookTestStatus === 'pending' ? 'Test läuft …' : 'Test ausführen'}
                </button>
              </div>
              {webhookTestStatus !== 'idle' && (
                <p
                  className={clsx('mt-3 text-sm', {
                    'text-brand-gold': webhookTestStatus === 'success',
                    'text-white/60': webhookTestStatus === 'pending',
                    'text-red-400': webhookTestStatus === 'error'
                  })}
                >
                  {webhookTestMessage}
                </p>
              )}
              <div className="mt-6 grid gap-4 md:grid-cols-2">
                <div>
                  <label className="text-xs uppercase tracking-[0.3em] text-white/40">Webhook URL</label>
                  <input
                    className="mt-2 w-full rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-white placeholder:text-white/40 focus:border-brand-gold/60 focus:outline-none"
                    placeholder="https://n8n.example.com/webhook/aiti-agent"
                    value={settings.webhookUrl}
                    onChange={(event) => updateSetting('webhookUrl', event.target.value)}
                  />
                </div>
                <div>
                  <label className="text-xs uppercase tracking-[0.3em] text-white/40">Authentifizierung</label>
                  <select
                    className="mt-2 w-full rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-white focus:border-brand-gold/60 focus:outline-none"
                    value={settings.authType}
                    onChange={(event) =>
                      updateSetting('authType', event.target.value as AgentAuthType)
                    }
                  >
                    <option value="none" className="bg-[#161616]">
                      Keine Authentifizierung
                    </option>
                    <option value="apiKey" className="bg-[#161616]">
                      API Key
                    </option>
                    <option value="basic" className="bg-[#161616]">
                      Basic Auth
                    </option>
                    <option value="oauth" className="bg-[#161616]">
                      OAuth 2.0
                    </option>
                  </select>
                </div>
                {settings.authType === 'apiKey' && (
                  <div className="md:col-span-2">
                    <label className="text-xs uppercase tracking-[0.3em] text-white/40">API Key</label>
                    <input
                      className="mt-2 w-full rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-white placeholder:text-white/40 focus:border-brand-gold/60 focus:outline-none"
                      placeholder="SuperSecretApiKey"
                      value={settings.apiKey ?? ''}
                      onChange={(event) => updateSetting('apiKey', event.target.value)}
                    />
                  </div>
                )}
                {settings.authType === 'basic' && (
                  <>
                    <div>
                      <label className="text-xs uppercase tracking-[0.3em] text-white/40">Benutzername</label>
                      <input
                        className="mt-2 w-full rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-white placeholder:text-white/40 focus:border-brand-gold/60 focus:outline-none"
                        placeholder="n8n-user"
                        value={settings.basicAuthUsername ?? ''}
                        onChange={(event) => updateSetting('basicAuthUsername', event.target.value)}
                      />
                    </div>
                    <div>
                      <label className="text-xs uppercase tracking-[0.3em] text-white/40">Passwort</label>
                      <input
                        type="password"
                        className="mt-2 w-full rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-white placeholder:text-white/40 focus:border-brand-gold/60 focus:outline-none"
                        placeholder="••••••••"
                        value={settings.basicAuthPassword ?? ''}
                        onChange={(event) => updateSetting('basicAuthPassword', event.target.value)}
                      />
                    </div>
                  </>
                )}
                {settings.authType === 'oauth' && (
                  <div className="md:col-span-2">
                    <label className="text-xs uppercase tracking-[0.3em] text-white/40">Access Token</label>
                    <input
                      className="mt-2 w-full rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-white placeholder:text-white/40 focus:border-brand-gold/60 focus:outline-none"
                      placeholder="ya29..."
                      value={settings.oauthToken ?? ''}
                      onChange={(event) => updateSetting('oauthToken', event.target.value)}
                    />
                  </div>
                )}
              </div>
            </div>
          </section>

          <aside className="lg:col-span-2 space-y-8">
            <div className="rounded-3xl border border-white/10 bg-[#161616]/70 p-8 shadow-2xl">
              <h3 className="text-xl font-semibold text-white">Agent Profilbild</h3>
              <div className="mt-6 flex flex-col gap-6 md:flex-row md:items-start">
                <div className="flex flex-col items-center gap-3">
                  <div className="h-24 w-24 overflow-hidden rounded-3xl border border-white/10 shadow-lg">
                    <img src={agentAvatarPreview} alt="Agent Avatar" className="h-full w-full object-cover" />
                  </div>
                  <button
                    type="button"
                    onClick={() => agentAvatarInputRef.current?.click()}
                    className="inline-flex items-center justify-center rounded-full bg-gradient-to-r from-brand-gold via-brand-deep to-brand-gold px-4 py-2 text-xs font-semibold uppercase tracking-[0.3em] text-surface-base shadow-glow"
                  >
                    Neu hochladen
                  </button>
                  <button
                    type="button"
                    onClick={handleAgentAvatarReset}
                    className="text-xs text-white/50 hover:text-white/80"
                  >
                    Zurücksetzen
                  </button>
                  <input
                    ref={agentAvatarInputRef}
                    type="file"
                    accept="image/*"
                    onChange={handleAgentAvatarUpload}
                    className="hidden"
                  />
                </div>
              </div>
            </div>

            <div className="rounded-3xl border border-white/10 bg-[#161616]/70 p-8 shadow-2xl">
              <h3 className="text-xl font-semibold text-white">Interface Optionen</h3>
              <div className="mt-6 space-y-4">
                <div>
                  <label className="text-xs uppercase tracking-[0.3em] text-white/40">Farbschema</label>
                  <div className="mt-3 grid gap-3 md:grid-cols-2">
                    {[
                      { value: 'dark' as const, label: 'Dark Mode' },
                      { value: 'light' as const, label: 'Light Mode' }
                    ].map((option) => (
                      <button
                        type="button"
                        key={option.value}
                        onClick={() => updateSetting('colorScheme', option.value)}
                        className={clsx(
                          'rounded-2xl border px-4 py-3 text-left transition',
                          settings.colorScheme === option.value
                            ? 'border-brand-gold/60 bg-white/10 text-white shadow-glow'
                            : 'border-white/10 bg-white/5 text-white/70 hover:bg-white/10'
                        )}
                        aria-pressed={settings.colorScheme === option.value}
                      >
                        <span className="block text-sm font-semibold text-white">{option.label}</span>
                      </button>
                    ))}
                  </div>
                </div>
              </div>
            </div>
          </aside>
          <div className="lg:col-span-5 flex justify-end">
            <button
              type="submit"
              className="inline-flex items-center gap-2 rounded-full bg-gradient-to-r from-brand-gold via-brand-deep to-brand-gold px-6 py-3 text-sm font-semibold text-surface-base shadow-glow transition hover:opacity-90"
            >
              Änderungen speichern
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
