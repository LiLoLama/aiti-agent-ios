import supabase from '../utils/supabase';

const AUDIO_BUCKET_NAME = 'audio';
const DEFAULT_AUDIO_MIME = 'audio/webm';
const MAX_WAVEFORM_VALUES = 128;

export interface AudioRecordingPayload {
  blob: Blob;
  mimeType: string;
  durationMs: number;
  waveform?: number[];
}

export interface AudioMessageUploadResult {
  messageId: string;
  storagePath: string;
  signedUrl: string;
  meta: {
    url: string;
    path: string;
    mime: string;
    duration_ms: number;
    waveform?: number[];
  };
}

const sanitizeDuration = (durationMs: number): number => {
  if (!Number.isFinite(durationMs)) {
    return 0;
  }

  return Math.max(0, Math.round(durationMs));
};

const sanitizeWaveform = (waveform?: number[]): number[] | undefined => {
  if (!Array.isArray(waveform) || waveform.length === 0) {
    return undefined;
  }

  const limited = waveform.slice(-MAX_WAVEFORM_VALUES);
  const sanitized = limited
    .map((value) => {
      if (!Number.isFinite(value)) {
        return null;
      }

      return Math.max(0, Math.min(255, Math.round(value)));
    })
    .filter((value): value is number => value !== null);

  return sanitized.length > 0 ? sanitized : undefined;
};

const deriveExtensionFromMime = (mimeType: string): string => {
  const normalized = mimeType.toLowerCase();

  if (normalized.includes('webm')) {
    return 'webm';
  }

  if (normalized.includes('mp4')) {
    return 'mp4';
  }

  if (normalized.includes('mpeg') || normalized.includes('mp3')) {
    return 'mp3';
  }

  if (normalized.includes('ogg')) {
    return 'ogg';
  }

  const parts = normalized.split('/');
  if (parts.length === 2 && parts[1]) {
    return parts[1];
  }

  return 'webm';
};

const generateMessageId = () => {
  if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') {
    return crypto.randomUUID();
  }

  return `${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
};

export const uploadAndPersistAudioMessage = async ({
  conversationId,
  recording
}: {
  conversationId: string;
  recording: AudioRecordingPayload;
}): Promise<AudioMessageUploadResult> => {
  const {
    data: { session }
  } = await supabase.auth.getSession();

  if (!session) {
    throw new Error('Nicht authentifiziert.');
  }

  const profileId = session.user.id;
  const mimeType = recording.mimeType?.trim() || DEFAULT_AUDIO_MIME;
  const durationMs = sanitizeDuration(recording.durationMs);
  const waveform = sanitizeWaveform(recording.waveform);
  const extension = deriveExtensionFromMime(mimeType);
  const timestamp = Date.now();
  const storagePath = `${profileId}/${conversationId}/${timestamp}.${extension}`;

  const { error: uploadError } = await supabase.storage
    .from(AUDIO_BUCKET_NAME)
    .upload(storagePath, recording.blob, {
      contentType: mimeType
    });

  if (uploadError) {
    throw new Error(uploadError.message ?? 'Audio konnte nicht hochgeladen werden.');
  }

  const { data: signedUrlData, error: signedUrlError } = await supabase.storage
    .from(AUDIO_BUCKET_NAME)
    .createSignedUrl(storagePath, 900);

  if (signedUrlError || !signedUrlData?.signedUrl) {
    throw new Error(signedUrlError?.message ?? 'Signierte URL konnte nicht erstellt werden.');
  }

  const meta = {
    url: signedUrlData.signedUrl,
    path: storagePath,
    mime: mimeType,
    duration_ms: durationMs,
    ...(waveform ? { waveform } : {})
  };

  const messageId = generateMessageId();

  const { error: insertError } = await supabase
    .from('messages')
    .insert({
      id: messageId,
      profile_id: profileId,
      conversation_id: conversationId,
      type: 'audio',
      content: null,
      meta
    });

  if (insertError) {
    throw new Error(insertError.message ?? 'Nachricht konnte nicht gespeichert werden.');
  }

  return {
    messageId,
    storagePath,
    signedUrl: signedUrlData.signedUrl,
    meta
  };
};
