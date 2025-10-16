import { FormEvent, useEffect, useMemo, useRef, useState } from 'react';
import { Navigate, useLocation, useNavigate } from 'react-router-dom';
import {
  ArrowLeftIcon,
  CheckCircleIcon,
  Cog6ToothIcon,
  PlusCircleIcon,
  TrashIcon,
  XCircleIcon,
  XMarkIcon
} from '@heroicons/react/24/outline';
import clsx from 'clsx';
import { useAuth } from '../context/AuthContext';
import { AgentProfile } from '../types/auth';
import { AgentSettings, toSettingsEventPayload } from '../types/settings';
import {
  loadAgentDraft,
  loadAgentSettings,
  loadProfileDraft,
  saveAgentDraft,
  saveAgentSettings,
  saveProfileDraft
} from '../utils/storage';
import { applyColorScheme } from '../utils/theme';
import { sendWebhookMessage } from '../utils/webhook';
import { prepareImageForStorage } from '../utils/image';
import {
  applyIntegrationSecretToSettings,
  fetchIntegrationSecret
} from '../services/integrationSecretsService';
import userAvatar from '../assets/default-user.svg';
import agentFallbackAvatar from '../assets/agent-avatar.png';
import { useToast } from '../context/ToastContext';

interface AgentFormState {
  name: string;
  description: string;
  tools: string;
  webhookUrl: string;
  avatarUrl: string | null;
}

type AgentModalState = { mode: 'create' } | { mode: 'edit'; agent: AgentProfile };

const createEmptyAgentForm = (): AgentFormState => ({
  name: '',
  description: '',
  tools: '',
  webhookUrl: '',
  avatarUrl: null
});

export function ProfilePage() {
  const {
    currentUser,
    users,
    updateProfile,
    toggleUserActive,
    logout,
    addAgent,
    updateAgent,
    removeAgent
  } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const { showToast } = useToast();
  const [name, setName] = useState('');
  const [bio, setBio] = useState('');
  const [avatarPreview, setAvatarPreview] = useState<string | null>(null);
  const [isSaving, setIsSaving] = useState(false);
  const [redirectAfterSave, setRedirectAfterSave] = useState(() =>
    Boolean((location.state as { onboarding?: boolean } | null)?.onboarding)
  );
  const [agentModal, setAgentModal] = useState<AgentModalState | null>(null);
  const [agentForm, setAgentForm] = useState<AgentFormState>(() => createEmptyAgentForm());
  const agentCreateDraftRef = useRef<AgentFormState>(createEmptyAgentForm());
  const profileDraftInitializedRef = useRef(false);
  const agentDraftInitializedRef = useRef(false);
  const agentDraftUserRef = useRef<string | null>(null);
  const [agentSaving, setAgentSaving] = useState(false);
  const [agentError, setAgentError] = useState<string | null>(null);
  const [agentSettings, setAgentSettings] = useState<AgentSettings>(() => loadAgentSettings());
  const [colorSchemeError, setColorSchemeError] = useState<string | null>(null);
  const [agentWebhookTestStatus, setAgentWebhookTestStatus] = useState<
    'idle' | 'pending' | 'success' | 'error'
  >('idle');
  const [agentWebhookTestMessage, setAgentWebhookTestMessage] = useState<string | null>(null);
  const [adminError, setAdminError] = useState<string | null>(null);

  if (!currentUser) {
    return <Navigate to="/login" replace />;
  }

  const displayedAvatar = avatarPreview ?? userAvatar;
  const userAgents = currentUser.agents;
  const agentAvatarPreview = agentForm.avatarUrl ?? agentFallbackAvatar;

  useEffect(() => {
    if (!currentUser) {
      setName('');
      setBio('');
      setAvatarPreview(null);
      profileDraftInitializedRef.current = false;
      return;
    }

    const storedDraft = loadProfileDraft(currentUser.id);
    if (storedDraft) {
      const draftName = storedDraft.name?.trim().length ? storedDraft.name : null;
      const fallbackName = currentUser.name.trim().length > 0 ? currentUser.name : 'Neuer Nutzer';
      setName(draftName ?? fallbackName);
      setBio(storedDraft.bio);
      setAvatarPreview(
        typeof storedDraft.avatarUrl === 'string' && storedDraft.avatarUrl.length > 0
          ? storedDraft.avatarUrl
          : currentUser.avatarUrl ?? null
      );
    } else {
      const fallbackName = currentUser.name.trim().length > 0 ? currentUser.name : 'Neuer Nutzer';
      setName(fallbackName);
      setBio(currentUser.bio ?? '');
      setAvatarPreview(currentUser.avatarUrl ?? null);
    }

    profileDraftInitializedRef.current = true;
  }, [currentUser]);

  useEffect(() => {
    if (!currentUser || !profileDraftInitializedRef.current) {
      return;
    }

    const normalizedName = name.trim();
    const baselineName = (currentUser.name ?? '').trim();
    const baselineBio = currentUser.bio ?? '';
    const baselineAvatar = currentUser.avatarUrl ?? null;
    const nextDraft = {
      name,
      bio,
      avatarUrl: avatarPreview
    };

    const hasChanges =
      normalizedName !== baselineName || bio !== baselineBio || (avatarPreview ?? null) !== baselineAvatar;

    if (hasChanges) {
      saveProfileDraft(currentUser.id, nextDraft);
    } else {
      saveProfileDraft(currentUser.id, null);
    }
  }, [avatarPreview, bio, currentUser, name]);

  useEffect(() => {
    if (!currentUser) {
      agentDraftInitializedRef.current = false;
      agentDraftUserRef.current = null;
      const emptyDraft = createEmptyAgentForm();
      agentCreateDraftRef.current = emptyDraft;
      setAgentForm(emptyDraft);
      return;
    }

    if (agentDraftInitializedRef.current && agentDraftUserRef.current === currentUser.id) {
      return;
    }

    const storedDraft = loadAgentDraft(currentUser.id);
    const nextDraft: AgentFormState = storedDraft
      ? {
          name: storedDraft.name,
          description: storedDraft.description,
          tools: storedDraft.tools,
          webhookUrl: storedDraft.webhookUrl,
          avatarUrl: storedDraft.avatarUrl
        }
      : createEmptyAgentForm();

    agentCreateDraftRef.current = nextDraft;
    if (!agentModal || agentModal.mode !== 'edit') {
      setAgentForm(nextDraft);
    }

    agentDraftInitializedRef.current = true;
    agentDraftUserRef.current = currentUser.id;
  }, [agentModal, currentUser]);

  useEffect(() => {
    if (!currentUser || !agentDraftInitializedRef.current || agentModal?.mode === 'edit') {
      return;
    }

    agentCreateDraftRef.current = agentForm;

    const hasContent =
      agentForm.name.trim().length > 0 ||
      agentForm.description.trim().length > 0 ||
      agentForm.tools.trim().length > 0 ||
      agentForm.webhookUrl.trim().length > 0 ||
      Boolean(agentForm.avatarUrl);

    if (hasContent) {
      saveAgentDraft(currentUser.id, agentForm);
    } else {
      saveAgentDraft(currentUser.id, null);
    }
  }, [agentForm, agentModal?.mode, currentUser]);

  useEffect(() => {
    applyColorScheme(agentSettings.colorScheme);
  }, [agentSettings.colorScheme]);

  useEffect(() => {
    if (!currentUser?.id) {
      return;
    }

    let isMounted = true;

    const syncIntegrationSecrets = async () => {
      try {
        const record = await fetchIntegrationSecret(currentUser.id);
        if (!isMounted) {
          return;
        }

        setAgentSettings((previous) => applyIntegrationSecretToSettings(previous, record));
      } catch (error) {
        console.error('Integrations-Secrets konnten nicht geladen werden.', error);
      }
    };

    void syncIntegrationSecrets();

    return () => {
      isMounted = false;
    };
  }, [currentUser?.id]);

  useEffect(() => {
    if (typeof window === 'undefined') {
      return;
    }

    const handleSettingsUpdate = (event: WindowEventMap['aiti-settings-update']) => {
      setAgentSettings((previous) => ({ ...previous, ...event.detail }));
      setColorSchemeError(null);
    };

    window.addEventListener('aiti-settings-update', handleSettingsUpdate);

    return () => {
      window.removeEventListener('aiti-settings-update', handleSettingsUpdate);
    };
  }, []);

  useEffect(() => {
    const state = location.state as { onboarding?: boolean; openAgentModal?: 'create' } | null;
    if (state?.openAgentModal === 'create') {
      setAgentForm(agentCreateDraftRef.current ?? createEmptyAgentForm());
      setAgentModal({ mode: 'create' });
      setAgentError(null);
      setAgentWebhookTestStatus('idle');
      setAgentWebhookTestMessage(null);
      navigate(location.pathname, {
        replace: true,
        state: state.onboarding ? { onboarding: state.onboarding } : undefined
      });
    }
  }, [location.pathname, location.state, navigate]);

  const handleAvatarUpload = async (file: File | null) => {
    if (!file) {
      return;
    }

    try {
      const result = await prepareImageForStorage(file, {
        maxDimension: 512,
        mimeType: 'image/jpeg',
        quality: 0.9
      });
      setAvatarPreview(result);
    } catch (error) {
      console.error('Profilbild konnte nicht verarbeitet werden.', error);
      showToast({
        type: 'error',
        title: 'Profilbild konnte nicht verarbeitet werden',
        description: 'Bitte versuche es mit einer anderen Datei.'
      });
    }
  };

  const resetAgentWebhookTest = () => {
    setAgentWebhookTestStatus('idle');
    setAgentWebhookTestMessage(null);
  };

  const openCreateAgentModal = () => {
    setAgentForm(agentCreateDraftRef.current ?? createEmptyAgentForm());
    setAgentModal({ mode: 'create' });
    setAgentError(null);
    resetAgentWebhookTest();
  };

  const openEditAgentModal = (agent: AgentProfile) => {
    setAgentForm({
      name: agent.name,
      description: agent.description,
      tools: agent.tools.join(', '),
      webhookUrl: agent.webhookUrl,
      avatarUrl: agent.avatarUrl
    });
    setAgentModal({ mode: 'edit', agent });
    setAgentError(null);
    resetAgentWebhookTest();
  };

  const closeAgentModal = (options?: { resetDraft?: boolean }) => {
    const previousModal = agentModal;
    setAgentModal(null);
    setAgentError(null);
    resetAgentWebhookTest();

    if (!previousModal) {
      return;
    }

    if (previousModal.mode === 'create') {
      if (options?.resetDraft) {
        const emptyDraft = createEmptyAgentForm();
        agentCreateDraftRef.current = emptyDraft;
        setAgentForm(emptyDraft);
        if (currentUser) {
          saveAgentDraft(currentUser.id, null);
        }
      } else {
        setAgentForm(agentCreateDraftRef.current);
      }
    } else if (previousModal.mode === 'edit') {
      setAgentForm(agentCreateDraftRef.current);
    }
  };

  const handleDeleteAgent = async (agentId: string) => {
    if (typeof window !== 'undefined') {
      const shouldDelete = window.confirm('Möchtest du diesen Agent wirklich löschen?');
      if (!shouldDelete) {
        return;
      }
    }

    const agentToRemove = currentUser.agents.find((agent) => agent.id === agentId);

    try {
      await removeAgent(agentId);
      showToast({
        type: 'success',
        title: 'Agent gelöscht',
        description: agentToRemove?.name ? `${agentToRemove.name} wurde entfernt.` : 'Agent wurde entfernt.'
      });
    } catch (error) {
      const message =
        error instanceof Error ? error.message : 'Agent konnte nicht gelöscht werden.';
      setAgentError(message);
      showToast({
        type: 'error',
        title: 'Agent konnte nicht gelöscht werden',
        description: message
      });
    }
  };

  const handleAgentAvatarUpload = async (file: File | null) => {
    if (!file) {
      return;
    }

    try {
      const result = await prepareImageForStorage(file, {
        maxDimension: 512,
        mimeType: 'image/jpeg',
        quality: 0.9
      });
      setAgentForm((previous) => ({ ...previous, avatarUrl: result }));
    } catch (error) {
      console.error('Agentenbild konnte nicht verarbeitet werden.', error);
      setAgentError('Agentenbild konnte nicht verarbeitet werden.');
    }
  };

  const performToggleUserActive = async (userId: string, nextActive: boolean) => {
    setAdminError(null);

    const affectedUser =
      users.find((user) => user.id === userId) ?? (currentUser.id === userId ? currentUser : null);

    try {
      await toggleUserActive(userId, nextActive);
      showToast({
        type: 'success',
        title: nextActive ? 'Nutzer aktiviert' : 'Nutzer deaktiviert',
        description: affectedUser
          ? `${affectedUser.name} wurde ${nextActive ? 'aktiviert' : 'deaktiviert'}.`
          : 'Status wurde aktualisiert.'
      });
    } catch (error) {
      const message =
        error instanceof Error
          ? error.message
          : 'Nutzerstatus konnte nicht aktualisiert werden.';
      setAdminError(message);
      showToast({
        type: 'error',
        title: 'Nutzerstatus konnte nicht aktualisiert werden',
        description: message
      });
    }
  };

  const handleAgentSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();

    const activeModal = agentModal;

    if (!activeModal) {
      return;
    }

    setAgentSaving(true);
    setAgentError(null);

    const tools = agentForm.tools
      .split(',')
      .map((tool) => tool.trim())
      .filter((tool) => tool.length > 0);

    try {
      if (activeModal.mode === 'create') {
        await addAgent({
          name: agentForm.name,
          description: agentForm.description,
          avatarUrl: agentForm.avatarUrl,
          tools,
          webhookUrl: agentForm.webhookUrl
        });
        const draftName = agentForm.name.trim().length > 0 ? agentForm.name.trim() : 'Neuer Agent';
        closeAgentModal({ resetDraft: true });
        showToast({
          type: 'success',
          title: 'Agent erstellt',
          description: `${draftName} wurde gespeichert.`
        });
      } else {
        await updateAgent(activeModal.agent.id, {
          name: agentForm.name,
          description: agentForm.description,
          avatarUrl: agentForm.avatarUrl,
          tools,
          webhookUrl: agentForm.webhookUrl
        });
        const updatedName =
          agentForm.name.trim().length > 0 ? agentForm.name.trim() : activeModal.agent.name;
        closeAgentModal();
        showToast({
          type: 'success',
          title: 'Agent aktualisiert',
          description: `${updatedName} wurde aktualisiert.`
        });
      }
    } catch (error) {
      const message =
        error instanceof Error ? error.message : 'Agent konnte nicht gespeichert werden.';
      setAgentError(message);
      showToast({
        type: 'error',
        title: 'Agent konnte nicht gespeichert werden',
        description: message
      });
    } finally {
      setAgentSaving(false);
    }
  };

  const handleSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();

    if (!currentUser) {
      return;
    }

    setIsSaving(true);

    try {
      await updateProfile({
        name,
        bio,
        avatarUrl: avatarPreview
      });
      saveProfileDraft(currentUser.id, null);
      showToast({
        type: 'success',
        title: 'Profil aktualisiert',
        description: 'Deine Änderungen wurden gespeichert.'
      });
      if (redirectAfterSave) {
        setRedirectAfterSave(false);
        setTimeout(() => navigate('/', { replace: true }), 600);
      }
    } catch (error) {
      const message =
        error instanceof Error ? error.message : 'Profil konnte nicht aktualisiert werden.';
      console.error(error);
      showToast({
        type: 'error',
        title: 'Profil konnte nicht gespeichert werden',
        description: message
      });
    } finally {
      setIsSaving(false);
    }
  };

  const adminVisibleUsers = useMemo(
    () => [...users].sort((a, b) => a.name.localeCompare(b.name)),
    [users]
  );

  const handleColorSchemeChange = (scheme: AgentSettings['colorScheme']) => {
    if (agentSettings.colorScheme === scheme) {
      return;
    }

    setColorSchemeError(null);
    const nextSettings: AgentSettings = {
      ...agentSettings,
      colorScheme: scheme
    };

    try {
      saveAgentSettings(nextSettings);
      setAgentSettings(nextSettings);
      if (typeof window !== 'undefined') {
        const eventPayload = toSettingsEventPayload(nextSettings);
        window.dispatchEvent(
          new CustomEvent('aiti-settings-update', {
            detail: eventPayload
          })
        );
      }
    } catch (error) {
      console.error('Farbschema konnte nicht gespeichert werden.', error);
      setColorSchemeError('Farbschema konnte nicht gespeichert werden. Bitte versuche es erneut.');
    }
  };

  const handleTestAgentWebhook = async () => {
    if (agentWebhookTestStatus === 'pending') {
      return;
    }

    const webhookUrl = agentForm.webhookUrl.trim();
    if (!webhookUrl) {
      setAgentWebhookTestStatus('error');
      setAgentWebhookTestMessage('Bitte gib zunächst eine Webhook URL an.');
      return;
    }

    setAgentWebhookTestStatus('pending');
    setAgentWebhookTestMessage('Webhook Test läuft …');

    try {
      const timestamp = new Date();
      const messageId =
        typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function'
          ? crypto.randomUUID()
          : `agent-test-${Math.random().toString(36).slice(2)}`;
      const chatId =
        typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function'
          ? crypto.randomUUID()
          : `agent-test-chat-${Math.random().toString(36).slice(2)}`;

      const webhookSettings: AgentSettings = {
        ...agentSettings,
        webhookUrl
      };

      const response = await sendWebhookMessage(webhookSettings, {
        chatId,
        message: 'Webhook Test',
        messageId,
        history: [
          {
            id: messageId,
            author: 'user',
            content: 'Webhook Test',
            timestamp: timestamp.toISOString()
          }
        ],
        attachments: []
      });

      const trimmedResponse = response.message.trim();
      const preview =
        trimmedResponse.length > 200 ? `${trimmedResponse.slice(0, 197)}…` : trimmedResponse;

      setAgentWebhookTestStatus('success');
      setAgentWebhookTestMessage(
        preview
          ? `Webhook Test erfolgreich. Antwort: ${preview}`
          : 'Webhook Test erfolgreich. Es wurde keine Nachricht zurückgegeben.'
      );
    } catch (error) {
      setAgentWebhookTestStatus('error');
      setAgentWebhookTestMessage(
        error instanceof Error
          ? `Webhook Test fehlgeschlagen: ${error.message}`
          : 'Webhook Test fehlgeschlagen. Unbekannter Fehler.'
      );
    }
  };

  const agentManagementContent = (
    <>
      <div className="mt-6 space-y-4">
        {userAgents.length === 0 ? (
          <div className="rounded-2xl border border-dashed border-white/15 bg-white/5 px-6 py-8 text-sm text-white/70">
            <p>Du hast noch keine Agents angelegt.</p>
            <p className="mt-2 text-xs text-white/50">
              Starte mit einem spezialisierten Agenten und erweitere dein Team Schritt für Schritt.
            </p>
          </div>
        ) : (
          userAgents.map((agent) => (
            <div
              key={agent.id}
              className="flex flex-col gap-4 rounded-3xl border border-white/10 bg-[#121212] p-6 md:flex-row md:items-start md:justify-between"
            >
              <div className="flex flex-1 items-start gap-4">
                <div className="h-16 w-16 overflow-hidden rounded-3xl border border-white/10 bg-white/5">
                  <img
                    src={agent.avatarUrl ?? agentFallbackAvatar}
                    alt={agent.name}
                    className="h-full w-full object-cover"
                  />
                </div>
                <div className="space-y-2">
                  <h3 className="text-lg font-semibold text-white">{agent.name}</h3>
                  <p className="text-sm text-white/60">
                    {agent.description
                      ? agent.description
                      : 'Beschreibe den Fokus dieses Agents in der Konfiguration.'}
                  </p>
                  {agent.tools.length > 0 && (
                    <div className="flex flex-wrap gap-2 pt-1 text-xs">
                      {agent.tools.map((tool) => (
                        <span key={tool} className="rounded-full bg-white/5 px-3 py-1 text-white/70">
                          {tool}
                        </span>
                      ))}
                    </div>
                  )}
                </div>
              </div>
              <div className="flex flex-col items-start gap-3 md:items-end md:text-right">
                <p className={`break-all text-xs ${agent.webhookUrl ? 'text-brand-gold' : 'text-white/40'}`}>
                  {agent.webhookUrl || 'Noch kein Webhook hinterlegt'}
                </p>
                <button
                  type="button"
                  onClick={() => openEditAgentModal(agent)}
                  className="inline-flex items-center gap-2 rounded-full border border-white/10 px-5 py-2 text-xs font-semibold text-white/70 transition hover:bg-white/10"
                >
                  <Cog6ToothIcon className="h-4 w-4" />
                  Konfigurieren
                </button>
                <button
                  type="button"
                  onClick={() => {
                    void handleDeleteAgent(agent.id);
                  }}
                  className="inline-flex items-center gap-2 rounded-full border border-red-500/40 px-5 py-2 text-xs font-semibold text-red-400 transition hover:border-red-400 hover:bg-red-500/10 hover:text-red-200"
                >
                  <TrashIcon className="h-4 w-4" />
                  Agent löschen
                </button>
              </div>
            </div>
          ))
        )}
      </div>
      <div className="mt-6">
        <button
          type="button"
          onClick={openCreateAgentModal}
          className="inline-flex items-center gap-2 rounded-full border border-dashed border-brand-gold/60 px-5 py-2 text-sm font-semibold text-brand-gold transition hover:border-brand-gold hover:bg-brand-gold/10 hover:text-white"
        >
          <PlusCircleIcon className="h-5 w-5" />
          Neuen Agent anlegen
        </button>
      </div>
    </>
  );

  return (
    <div className="min-h-screen bg-[#0d0d0d] pb-20 text-white">
      <div className="mx-auto flex max-w-6xl flex-col gap-10 px-4 pt-10 md:px-8">
        <button
          onClick={() => navigate(-1)}
          className="inline-flex items-center gap-2 text-sm text-white/50 transition hover:text-white"
        >
          <ArrowLeftIcon className="h-4 w-4" /> Zurück
        </button>

        <div className="grid grid-cols-1 gap-8 lg:grid-cols-[1.05fr_0.95fr]">
          <section className="rounded-[32px] border border-white/10 bg-[#141414]/90 p-8 shadow-2xl">
            <header className="flex flex-wrap items-center justify-between gap-4">
              <div>
                <p className="text-xs uppercase tracking-[0.35em] text-white/40">Profil</p>
                <h1 className="mt-2 text-3xl font-semibold">Dein persönlicher Bereich</h1>
              </div>
              <button
                onClick={async () => {
                  await logout();
                  navigate('/login', { replace: true });
                }}
                className="rounded-full border border-white/20 px-5 py-2 text-xs font-semibold text-white/70 transition hover:bg-white/10"
              >
                Logout
              </button>
            </header>

            <form className="mt-10 space-y-8" onSubmit={handleSubmit}>
              <div className="flex flex-col gap-6 md:flex-row">
                <div className="flex flex-col items-center gap-3 text-center md:w-52">
                  <div className="relative h-32 w-32 overflow-hidden rounded-3xl border border-white/10 bg-black/30">
                    <img src={displayedAvatar} alt={name} className="h-full w-full object-cover" />
                  </div>
                  <label className="cursor-pointer text-xs font-semibold text-brand-gold hover:underline">
                    Neues Bild hochladen
                    <input
                      type="file"
                      className="hidden"
                      accept="image/*"
                      onChange={(event) => handleAvatarUpload(event.target.files?.[0] ?? null)}
                    />
                  </label>
                  {avatarPreview && (
                    <button
                      type="button"
                      className="text-xs text-white/50 hover:text-white"
                      onClick={() => setAvatarPreview(null)}
                    >
                      Zurücksetzen
                    </button>
                  )}
                </div>

                <div className="flex-1 space-y-5">
                  <div>
                    <label className="text-xs font-medium uppercase tracking-[0.35em] text-white/40">Name</label>
                    <input
                      type="text"
                      className="mt-2 w-full rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-white focus:border-brand-gold focus:outline-none focus:ring-2 focus:ring-brand-gold/30"
                      value={name}
                      onChange={(event) => setName(event.target.value)}
                      required
                    />
                  </div>
                  <div>
                    <label className="text-xs font-medium uppercase tracking-[0.35em] text-white/40">E-Mail</label>
                    <input
                      type="email"
                      className="mt-2 w-full cursor-not-allowed rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-white/60"
                      value={currentUser.email}
                      readOnly
                    />
                  </div>
                  <div>
                    <label className="text-xs font-medium uppercase tracking-[0.35em] text-white/40">Beschreibung</label>
                    <textarea
                      className="mt-2 min-h-[120px] w-full rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-white focus:border-brand-gold focus:outline-none focus:ring-2 focus:ring-brand-gold/30"
                      placeholder="Beschreibe dich oder deine Arbeitsweise mit dem AITI Agent."
                      value={bio}
                      onChange={(event) => setBio(event.target.value)}
                    />
                  </div>
                  <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
                    <div className="rounded-2xl border border-white/10 bg-white/5 p-4 sm:col-span-2">
                      <p className="text-xs uppercase tracking-[0.35em] text-white/40">Status</p>
                      <p className="mt-2 inline-flex items-center gap-2 text-sm font-semibold">
                        {currentUser.isActive ? (
                          <>
                            <CheckCircleIcon className="h-4 w-4 text-emerald-400" /> Aktiv
                          </>
                        ) : (
                          <>
                            <XCircleIcon className="h-4 w-4 text-rose-400" /> Deaktiviert
                          </>
                        )}
                      </p>
                      <p className="mt-1 text-xs text-white/60">
                        {currentUser.isActive
                          ? 'Dein Account ist aktiv und kann Agents sowie Chats verwalten.'
                          : 'Dein Account ist aktuell deaktiviert. Wende dich an den Workspace-Admin für Unterstützung.'}
                      </p>
                    </div>
                    <div className="rounded-2xl border border-white/10 bg-white/5 p-4 sm:col-span-2">
                      <p className="text-xs uppercase tracking-[0.35em] text-white/40">Agents erstellt</p>
                      <p className="mt-2 text-sm font-semibold text-white">{userAgents.length}</p>
                      <p className="mt-1 text-xs text-white/60">
                        {userAgents.length === 1
                          ? 'Du hast bisher einen Agent angelegt.'
                          : `Du hast bisher ${userAgents.length} Agents angelegt.`}
                      </p>
                    </div>
                  </div>
                  <div className="rounded-2xl border border-white/10 bg-white/5 p-4">
                    <p className="text-xs uppercase tracking-[0.35em] text-white/40">Farbschema</p>
                    <div className="mt-3 grid gap-3 sm:grid-cols-2">
                      {[
                        { value: 'dark' as const, label: 'Dark Mode' },
                        { value: 'light' as const, label: 'Light Mode' }
                      ].map((option) => (
                        <button
                          type="button"
                          key={option.value}
                          onClick={() => handleColorSchemeChange(option.value)}
                          className={clsx(
                            'rounded-2xl border px-4 py-3 text-left transition',
                            agentSettings.colorScheme === option.value
                              ? 'border-brand-gold/60 bg-white/10 text-white shadow-glow'
                              : 'border-white/10 bg-white/5 text-white/70 hover:bg-white/10'
                          )}
                          aria-pressed={agentSettings.colorScheme === option.value}
                        >
                          <span className="block text-sm font-semibold text-white">{option.label}</span>
                        </button>
                      ))}
                    </div>
                    {colorSchemeError && (
                      <p className="mt-3 text-xs text-rose-300">{colorSchemeError}</p>
                    )}
                  </div>
                </div>
              </div>

              <div className="flex flex-wrap items-center gap-3">
                <button
                  type="submit"
                  disabled={isSaving}
                  className="rounded-full bg-gradient-to-r from-brand-gold via-brand-deep to-brand-gold px-6 py-3 text-sm font-semibold text-black shadow-glow transition hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-60"
                >
                  {isSaving ? 'Speichern …' : 'Änderungen speichern'}
                </button>
                <button
                  type="button"
                  className="text-sm text-white/50 hover:text-white"
                  onClick={() => {
                    setName(currentUser.name);
                    setBio(currentUser.bio ?? '');
                    setAvatarPreview(currentUser.avatarUrl ?? null);
                  }}
                >
                  Änderungen verwerfen
                </button>
              </div>
            </form>
          </section>

          <section className="space-y-6">
            <div className="rounded-[32px] border border-white/10 bg-[#141414]/90 p-8 shadow-2xl">
              {currentUser.role === 'admin' ? (
                <>
                  <header>
                    <p className="text-xs uppercase tracking-[0.35em] text-white/40">Team</p>
                    <h2 className="mt-2 text-2xl font-semibold">Nutzerübersicht</h2>
                    <p className="mt-2 text-sm text-white/60">
                      Verwalte die Zugänge deines Teams und behalte die Aktivität im Blick.
                    </p>
                  </header>
                  <div className="mt-6 overflow-hidden rounded-2xl border border-white/10">
                    <table className="min-w-full divide-y divide-white/10 text-left text-sm">
                      <thead className="bg-white/5 text-white/60">
                        <tr>
                          <th className="px-4 py-3 font-medium">Name</th>
                          <th className="px-4 py-3 font-medium">E-Mail</th>
                          <th className="px-4 py-3 font-medium">Agents</th>
                          <th className="px-4 py-3 font-medium">Status</th>
                          <th className="px-4 py-3 font-medium text-right">Aktionen</th>
                        </tr>
                      </thead>
                      <tbody className="divide-y divide-white/10 bg-[#121212]">
                        {adminError && (
                          <tr>
                            <td colSpan={5} className="px-4 py-3 text-sm text-rose-300">
                              {adminError}
                            </td>
                          </tr>
                        )}
                        {adminVisibleUsers.map((user) => (
                          <tr key={user.id} className="text-white/80">
                            <td className="px-4 py-3">
                              <div className="flex items-center gap-3">
                                <span className="inline-flex h-9 w-9 items-center justify-center rounded-full bg-white/5 text-xs font-semibold uppercase text-white/70">
                                  {user.name
                                    .split(' ')
                                    .map((part) => part[0])
                                    .slice(0, 2)
                                    .join('')}
                                </span>
                                <div>
                                  <p className="font-semibold text-white">{user.name}</p>
                                  <p className="text-xs text-white/40">{user.role === 'admin' ? 'Admin' : 'Nutzer'}</p>
                                </div>
                              </div>
                            </td>
                            <td className="px-4 py-3">{user.email}</td>
                            <td className="px-4 py-3">{user.agents.length}</td>
                            <td className="px-4 py-3">
                              {user.isActive ? (
                                <span className="inline-flex items-center gap-2 rounded-full bg-emerald-500/10 px-3 py-1 text-xs font-semibold text-emerald-300">
                                  <CheckCircleIcon className="h-4 w-4" /> Aktiv
                                </span>
                              ) : (
                                <span className="inline-flex items-center gap-2 rounded-full bg-rose-500/10 px-3 py-1 text-xs font-semibold text-rose-300">
                                  <XCircleIcon className="h-4 w-4" /> Inaktiv
                                </span>
                              )}
                            </td>
                            <td className="px-4 py-3 text-right">
                              <button
                                type="button"
                                onClick={() => {
                                  void performToggleUserActive(user.id, !user.isActive);
                                }}
                                className="rounded-full border border-white/10 px-4 py-2 text-xs font-semibold text-white/70 transition hover:bg-white/10 disabled:opacity-40"
                                disabled={user.id === currentUser.id}
                              >
                                {user.isActive ? 'Deaktivieren' : 'Aktivieren'}
                              </button>
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                </>
              ) : (
                <>
                  <header>
                    <p className="text-xs uppercase tracking-[0.35em] text-white/40">Team</p>
                    <h2 className="mt-2 text-2xl font-semibold">Deine Agents</h2>
                  </header>
                  {agentManagementContent}
                </>
              )}
            </div>

            {currentUser.role === 'admin' && (
              <div className="rounded-[32px] border border-white/10 bg-[#141414]/90 p-8 shadow-2xl">
                <header>
                  <p className="text-xs uppercase tracking-[0.35em] text-white/40">Agents</p>
                  <h2 className="mt-2 text-2xl font-semibold">Eigene Agents verwalten</h2>
                  <p className="mt-2 text-sm text-white/60">
                    Passe Beschreibung, Tools und Webhook deiner Agents an.
                  </p>
                </header>
                {agentManagementContent}
              </div>
            )}

            <div className="rounded-[32px] border border-white/10 bg-[#141414]/90 p-8 shadow-2xl">
              <p className="text-xs uppercase tracking-[0.35em] text-white/40">Tipps</p>
              <h3 className="mt-2 text-xl font-semibold">So nutzt du den AITI Agent optimal</h3>
              <ul className="mt-4 space-y-3 text-sm text-white/70">
                <li>• Halte deine Profilinformationen aktuell.</li>
                <li>• Nutze für jeden Agent einen eigenen Webhook.</li>
                <li>• Ein einzelner Agent muss nicht alles können. Baue ein Team aus Experten.</li>
              </ul>
            </div>
          </section>
        </div>
      </div>
      {agentModal && (
        <div
          className="fixed inset-0 z-50 overflow-y-auto bg-black/60 px-4 py-10"
          onClick={() => closeAgentModal()}
        >
          <div className="mx-auto flex min-h-full w-full max-w-2xl items-center justify-center">
            <div
              className="relative w-full rounded-[32px] border border-white/10 bg-[#141414] p-8 text-white shadow-2xl"
              onClick={(event) => event.stopPropagation()}
            >
              <button
                type="button"
                onClick={() => closeAgentModal()}
                className="absolute right-5 top-5 rounded-full border border-white/10 p-2 text-white/60 transition hover:bg-white/10 hover:text-white"
              >
                <XMarkIcon className="h-5 w-5" />
              </button>
              <h3 className="text-2xl font-semibold">
                {agentModal.mode === 'create'
                  ? 'Neuen Agent anlegen'
                  : `${agentModal.agent.name} konfigurieren`}
              </h3>
              <p className="mt-2 text-sm text-white/60">
                Verleihe deinem Agenten ein klares Profil und lege Tools sowie Webhook fest.
              </p>
              <form className="mt-8 space-y-6" onSubmit={handleAgentSubmit}>
              <div className="flex flex-col gap-6 md:flex-row">
                <div className="flex flex-col items-center gap-3 text-center md:w-52">
                  <div className="relative h-28 w-28 overflow-hidden rounded-3xl border border-white/10 bg-black/30">
                    <img
                      src={agentAvatarPreview}
                      alt={agentForm.name || 'Agent'}
                      className="h-full w-full object-cover"
                    />
                  </div>
                  <label className="cursor-pointer text-xs font-semibold text-brand-gold hover:underline">
                    Neues Bild hochladen
                    <input
                      type="file"
                      className="hidden"
                      accept="image/*"
                      onChange={(event) => handleAgentAvatarUpload(event.target.files?.[0] ?? null)}
                    />
                  </label>
                  {agentForm.avatarUrl && (
                    <button
                      type="button"
                      className="text-xs text-white/50 hover:text-white"
                      onClick={() => setAgentForm((previous) => ({ ...previous, avatarUrl: null }))}
                    >
                      Bild entfernen
                    </button>
                  )}
                </div>
                <div className="flex-1 space-y-5">
                  <div>
                    <label className="text-xs font-medium uppercase tracking-[0.35em] text-white/40">Name</label>
                    <input
                      type="text"
                      className="mt-2 w-full rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-white focus:border-brand-gold focus:outline-none focus:ring-2 focus:ring-brand-gold/30"
                      placeholder="Wie heißt dein Agent?"
                      value={agentForm.name}
                      onChange={(event) => setAgentForm((previous) => ({ ...previous, name: event.target.value }))}
                      required
                    />
                  </div>
                  <div>
                    <label className="text-xs font-medium uppercase tracking-[0.35em] text-white/40">Beschreibung</label>
                    <textarea
                      className="mt-2 min-h-[100px] w-full rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-white focus:border-brand-gold focus:outline-none focus:ring-2 focus:ring-brand-gold/30"
                      placeholder="Wofür setzt du diesen Agenten ein?"
                      value={agentForm.description}
                      onChange={(event) =>
                        setAgentForm((previous) => ({ ...previous, description: event.target.value }))
                      }
                    />
                  </div>
                  <div>
                    <label className="text-xs font-medium uppercase tracking-[0.35em] text-white/40">
                      Verfügbare Tools
                    </label>
                    <input
                      type="text"
                      className="mt-2 w-full rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-white focus:border-brand-gold focus:outline-none focus:ring-2 focus:ring-brand-gold/30"
                      placeholder="Tool A, Tool B, Tool C"
                      value={agentForm.tools}
                      onChange={(event) => setAgentForm((previous) => ({ ...previous, tools: event.target.value }))}
                    />
                  </div>
                  <div>
                    <label className="text-xs font-medium uppercase tracking-[0.35em] text-white/40">Webhook</label>
                    <input
                      type="url"
                      className="mt-2 w-full rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-white focus:border-brand-gold focus:outline-none focus:ring-2 focus:ring-brand-gold/30"
                      placeholder="https://hooks.example.com/dein-agent"
                      value={agentForm.webhookUrl}
                      onChange={(event) => {
                        const value = event.target.value;
                        setAgentForm((previous) => ({ ...previous, webhookUrl: value }));
                        if (agentWebhookTestStatus !== 'idle') {
                          resetAgentWebhookTest();
                        }
                      }}
                    />
                    <div className="mt-3">
                      <button
                        type="button"
                        onClick={handleTestAgentWebhook}
                        disabled={agentWebhookTestStatus === 'pending'}
                        className="inline-flex items-center justify-center rounded-full border border-white/15 bg-white/5 px-4 py-2 text-xs font-semibold text-white/80 transition hover:bg-white/10 disabled:cursor-not-allowed disabled:opacity-60"
                      >
                        {agentWebhookTestStatus === 'pending' ? 'Test läuft …' : 'Webhook testen'}
                      </button>
                    </div>
                    {agentWebhookTestStatus !== 'idle' && agentWebhookTestMessage && (
                      <div
                        className={clsx(
                          'mt-3 rounded-2xl border px-4 py-3 text-xs',
                          agentWebhookTestStatus === 'success'
                            ? 'border-emerald-500/40 bg-emerald-500/10 text-emerald-200'
                            : agentWebhookTestStatus === 'pending'
                              ? 'border-brand-gold/40 bg-brand-gold/10 text-brand-gold'
                              : 'border-rose-500/40 bg-rose-500/10 text-rose-200'
                        )}
                      >
                        {agentWebhookTestMessage}
                      </div>
                    )}
                  </div>
                </div>
              </div>
              {agentError && (
                <div className="rounded-2xl border border-rose-500/40 bg-rose-500/10 px-4 py-3 text-sm text-rose-200">
                  {agentError}
                </div>
              )}
              <div className="flex flex-wrap items-center gap-3">
                <button
                  type="submit"
                  disabled={agentSaving}
                  className="rounded-full bg-gradient-to-r from-brand-gold via-brand-deep to-brand-gold px-6 py-3 text-sm font-semibold text-black shadow-glow transition hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-60"
                >
                  {agentSaving
                    ? 'Speichern …'
                    : agentModal.mode === 'create'
                      ? 'Agent anlegen'
                      : 'Agent speichern'}
                </button>
                <button
                  type="button"
                  onClick={() => closeAgentModal()}
                  className="text-sm text-white/50 hover:text-white"
                >
                  Abbrechen
                </button>
              </div>
            </form>
          </div>
        </div>
      </div>
      )}
    </div>
  );
}
