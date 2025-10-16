import {
  MicrophoneIcon,
  PaperAirplaneIcon,
  PaperClipIcon,
  XMarkIcon
} from '@heroicons/react/24/outline';
import {
  ChangeEvent,
  FormEvent,
  KeyboardEvent,
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState
} from 'react';

const RECORDING_MAX_DURATION_MS = 120_000;
const WAVEFORM_BAR_COUNT = 24;
const WAVEFORM_SAMPLE_INTERVAL_MS = 100;

interface AudioPreview {
  blob: Blob;
  url: string;
  mimeType: string;
  durationMs: number;
  waveform?: number[];
}

export interface AudioRecordingSubmission {
  blob: Blob;
  mimeType: string;
  durationMs: number;
  waveform?: number[];
}

export interface ChatInputSubmission {
  text: string;
  files: File[];
  audio?: AudioRecordingSubmission;
}

interface ChatInputProps {
  onSendMessage: (payload: ChatInputSubmission) => Promise<void> | void;
  pushToTalkEnabled?: boolean;
}

const formatFileSize = (size: number) => {
  if (size >= 1024 * 1024) {
    return `${(size / (1024 * 1024)).toFixed(1)} MB`;
  }

  if (size >= 1024) {
    return `${Math.round(size / 1024)} KB`;
  }

  return `${size} B`;
};

const formatDuration = (durationMs: number) => {
  const totalSeconds = Math.max(0, Math.floor(durationMs / 1000));
  const minutes = Math.floor(totalSeconds / 60)
    .toString()
    .padStart(2, '0');
  const seconds = (totalSeconds % 60).toString().padStart(2, '0');

  return `${minutes}:${seconds}`;
};

const createInitialWaveform = () => Array.from({ length: WAVEFORM_BAR_COUNT }, () => 0);

export function ChatInput({ onSendMessage, pushToTalkEnabled = true }: ChatInputProps) {
  const [message, setMessage] = useState('');
  const [selectedFiles, setSelectedFiles] = useState<File[]>([]);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const fileInputRef = useRef<HTMLInputElement | null>(null);
  const textareaRef = useRef<HTMLTextAreaElement | null>(null);

  const mediaRecorderRef = useRef<MediaRecorder | null>(null);
  const mediaStreamRef = useRef<MediaStream | null>(null);
  const audioChunksRef = useRef<Blob[]>([]);
  const recorderMimeTypeRef = useRef<string | null>(null);
  const recordingStartedAtRef = useRef<number | null>(null);
  const audioContextRef = useRef<AudioContext | null>(null);
  const analyserNodeRef = useRef<AnalyserNode | null>(null);
  const animationFrameRef = useRef<number | null>(null);
  const timerIntervalRef = useRef<number | null>(null);
  const maxDurationTimeoutRef = useRef<number | null>(null);
  const waveformSamplesRef = useRef<number[]>([]);
  const lastWaveSampleTimeRef = useRef<number>(0);

  const [isRecording, setIsRecording] = useState(false);
  const [recordingDurationMs, setRecordingDurationMs] = useState(0);
  const [waveformBars, setWaveformBars] = useState<number[]>(createInitialWaveform);
  const [audioPreview, setAudioPreview] = useState<AudioPreview | null>(null);
  const [recordingError, setRecordingError] = useState<string | null>(null);
  const [recordingUnsupported, setRecordingUnsupported] = useState(false);
  const [isAudioSending, setIsAudioSending] = useState(false);

  const canSubmit = useMemo(() => {
    return Boolean(message.trim() || selectedFiles.length > 0);
  }, [message, selectedFiles]);

  const cleanupRecordingResources = useCallback(() => {
    if (animationFrameRef.current !== null) {
      cancelAnimationFrame(animationFrameRef.current);
      animationFrameRef.current = null;
    }

    if (timerIntervalRef.current !== null) {
      window.clearInterval(timerIntervalRef.current);
      timerIntervalRef.current = null;
    }

    if (maxDurationTimeoutRef.current !== null) {
      window.clearTimeout(maxDurationTimeoutRef.current);
      maxDurationTimeoutRef.current = null;
    }

    if (mediaStreamRef.current) {
      mediaStreamRef.current.getTracks().forEach((track) => track.stop());
      mediaStreamRef.current = null;
    }

    if (audioContextRef.current) {
      void audioContextRef.current.close().catch(() => undefined);
      audioContextRef.current = null;
    }

    analyserNodeRef.current = null;
    lastWaveSampleTimeRef.current = 0;
  }, []);

  const resetAudioState = useCallback(() => {
    cleanupRecordingResources();

    audioChunksRef.current = [];
    recorderMimeTypeRef.current = null;
    recordingStartedAtRef.current = null;
    waveformSamplesRef.current = [];

    setIsRecording(false);
    setRecordingDurationMs(0);
    setWaveformBars(createInitialWaveform);

    setAudioPreview((previous) => {
      if (previous?.url) {
        URL.revokeObjectURL(previous.url);
      }

      return null;
    });
  }, [cleanupRecordingResources]);

  useEffect(() => {
    return () => {
      if (mediaRecorderRef.current && mediaRecorderRef.current.state !== 'inactive') {
        try {
          mediaRecorderRef.current.stop();
        } catch (error) {
          console.error('Recorder konnte nicht gestoppt werden.', error);
        }
      }

      cleanupRecordingResources();
    };
  }, [cleanupRecordingResources]);

  useEffect(() => {
    return () => {
      if (audioPreview?.url) {
        URL.revokeObjectURL(audioPreview.url);
      }
    };
  }, [audioPreview]);

  useEffect(() => {
    const textarea = textareaRef.current;
    if (!textarea) {
      return;
    }

    textarea.style.height = '0px';
    textarea.style.height = `${textarea.scrollHeight}px`;
  }, [message]);

  const handleFileChange = (event: ChangeEvent<HTMLInputElement>) => {
    const files = Array.from(event.target.files ?? []);
    if (!files.length) {
      return;
    }

    setSelectedFiles((prev) => [...prev, ...files]);
    event.target.value = '';
  };

  const handleRemoveFile = (index: number) => {
    setSelectedFiles((prev) => prev.filter((_, fileIndex) => fileIndex !== index));
  };

  const ensureMediaRecorderSupport = async () => {
    if (typeof window === 'undefined') {
      return false;
    }

    if (typeof window.MediaRecorder !== 'undefined') {
      return true;
    }

    try {
      const module = await import('audio-recorder-polyfill');
      const AudioRecorderPolyfill = module.default ?? module;
      (window as typeof window & { MediaRecorder: typeof MediaRecorder }).MediaRecorder =
        AudioRecorderPolyfill as unknown as typeof MediaRecorder;
      return true;
    } catch (error) {
      console.error('MediaRecorder Polyfill konnte nicht geladen werden.', error);
      return false;
    }
  };

  const requestAudioStream = async () => {
    if (navigator.mediaDevices?.getUserMedia) {
      return navigator.mediaDevices.getUserMedia({ audio: true });
    }

    const legacyGetUserMedia =
      (navigator as any).getUserMedia ||
      (navigator as any).webkitGetUserMedia ||
      (navigator as any).mozGetUserMedia ||
      (navigator as any).msGetUserMedia;

    if (legacyGetUserMedia) {
      return new Promise<MediaStream>((resolve, reject) => {
        legacyGetUserMedia.call(navigator, { audio: true }, resolve, reject);
      });
    }

    throw new Error('unsupported');
  };

  const updateWaveformVisualization = useCallback(() => {
    const analyser = analyserNodeRef.current;
    if (!analyser) {
      animationFrameRef.current = requestAnimationFrame(updateWaveformVisualization);
      return;
    }

    const bufferLength = analyser.fftSize;
    const dataArray = new Uint8Array(bufferLength);
    analyser.getByteTimeDomainData(dataArray);

    let sum = 0;
    for (let index = 0; index < dataArray.length; index += 1) {
      sum += Math.abs(dataArray[index] - 128);
    }

    const average = Math.min(255, (sum / dataArray.length) * 2);
    const now = performance.now();
    if (now - lastWaveSampleTimeRef.current >= WAVEFORM_SAMPLE_INTERVAL_MS) {
      lastWaveSampleTimeRef.current = now;
      waveformSamplesRef.current.push(average);
      if (waveformSamplesRef.current.length > 256) {
        waveformSamplesRef.current.shift();
      }

      const recent = waveformSamplesRef.current.slice(-WAVEFORM_BAR_COUNT);
      const padded = Array.from({ length: WAVEFORM_BAR_COUNT }, (_, index) => {
        const value = recent[recent.length - WAVEFORM_BAR_COUNT + index];
        return Number.isFinite(value) ? Math.max(0, Math.min(1, value / 255)) : 0;
      });

      setWaveformBars(padded);
    }

    animationFrameRef.current = requestAnimationFrame(updateWaveformVisualization);
  }, []);

  const handleRecorderStop = useCallback(() => {
    cleanupRecordingResources();

    const chunks = audioChunksRef.current;
    audioChunksRef.current = [];
    const mimeType = recorderMimeTypeRef.current ?? 'audio/webm';
    recorderMimeTypeRef.current = null;

    if (!chunks.length) {
      setRecordingError('Es wurden keine Audiodaten aufgezeichnet.');
      return;
    }

    const blob = new Blob(chunks, { type: mimeType });
    const url = URL.createObjectURL(blob);
    const startedAt = recordingStartedAtRef.current;
    recordingStartedAtRef.current = null;
    const duration = startedAt ? Date.now() - startedAt : recordingDurationMs;
    const effectiveDuration = Math.min(RECORDING_MAX_DURATION_MS, Math.max(0, duration));
    const waveform = waveformSamplesRef.current.slice();
    waveformSamplesRef.current = [];
    setWaveformBars(createInitialWaveform());

    setAudioPreview({
      blob,
      url,
      mimeType,
      durationMs: effectiveDuration,
      waveform: waveform.length ? waveform : undefined
    });
    setRecordingDurationMs(effectiveDuration);
  }, [cleanupRecordingResources, recordingDurationMs]);

  const startRecording = useCallback(async () => {
    if (!pushToTalkEnabled) {
      setRecordingError('Die Audioaufnahme ist in den Einstellungen deaktiviert.');
      return;
    }

    if (isRecording || isAudioSending) {
      return;
    }

    setRecordingError(null);
    setRecordingUnsupported(false);

    if (!(await ensureMediaRecorderSupport())) {
      setRecordingUnsupported(true);
      setRecordingError('Audioaufnahme wird von deinem Browser nicht unterstützt.');
      return;
    }

    try {
      const stream = await requestAudioStream();
      resetAudioState();
      setRecordingDurationMs(0);

      mediaStreamRef.current = stream;

      const supportedMimeType =
        typeof MediaRecorder.isTypeSupported === 'function'
          ? ['audio/webm;codecs=opus', 'audio/webm', 'audio/mp4', 'audio/mpeg'].find((candidate) =>
              MediaRecorder.isTypeSupported(candidate)
            )
          : undefined;

      const recorder = supportedMimeType
        ? new MediaRecorder(stream, { mimeType: supportedMimeType })
        : new MediaRecorder(stream);

      recorderMimeTypeRef.current = recorder.mimeType || supportedMimeType || null;
      mediaRecorderRef.current = recorder;
      recordingStartedAtRef.current = Date.now();
      waveformSamplesRef.current = [];
      setWaveformBars(createInitialWaveform());

      recorder.addEventListener('dataavailable', (event) => {
        if (event.data.size > 0) {
          audioChunksRef.current.push(event.data);
        }
      });

      recorder.addEventListener('stop', () => {
        mediaRecorderRef.current = null;
        handleRecorderStop();
      });

      const AudioContextClass =
        typeof window !== 'undefined'
          ? (window.AudioContext || (window as typeof window & { webkitAudioContext?: typeof AudioContext })
              .webkitAudioContext)
          : null;

      if (AudioContextClass) {
        const audioContext = new AudioContextClass();
        audioContextRef.current = audioContext;
        const source = audioContext.createMediaStreamSource(stream);
        const analyser = audioContext.createAnalyser();
        analyser.fftSize = 512;
        source.connect(analyser);
        analyserNodeRef.current = analyser;
        waveformSamplesRef.current = [];
        lastWaveSampleTimeRef.current = 0;
        animationFrameRef.current = requestAnimationFrame(updateWaveformVisualization);
      } else {
        analyserNodeRef.current = null;
        waveformSamplesRef.current = [];
        setWaveformBars(createInitialWaveform());
      }

      timerIntervalRef.current = window.setInterval(() => {
        if (recordingStartedAtRef.current) {
          setRecordingDurationMs(Date.now() - recordingStartedAtRef.current);
        }
      }, 200);

      maxDurationTimeoutRef.current = window.setTimeout(() => {
        stopRecording();
      }, RECORDING_MAX_DURATION_MS);

      recorder.start();
      setIsRecording(true);
    } catch (error) {
      console.error('Audioaufnahme konnte nicht gestartet werden.', error);
      setRecordingError(
        error instanceof Error && error.message === 'unsupported'
          ? 'Audioaufnahme wird von deinem Browser nicht unterstützt.'
          : 'Audioaufnahme konnte nicht gestartet werden. Prüfe die Mikrofonrechte.'
      );

      if (mediaStreamRef.current) {
        mediaStreamRef.current.getTracks().forEach((track) => track.stop());
        mediaStreamRef.current = null;
      }
      cleanupRecordingResources();
    }
  }, [cleanupRecordingResources, handleRecorderStop, isAudioSending, isRecording, pushToTalkEnabled, resetAudioState, updateWaveformVisualization]);

  const stopRecording = useCallback(() => {
    const recorder = mediaRecorderRef.current;
    if (!recorder) {
      cleanupRecordingResources();
      setIsRecording(false);
      return;
    }

    try {
      if (recorder.state !== 'inactive') {
        recorder.stop();
      }
    } catch (error) {
      console.error('Aufnahme konnte nicht gestoppt werden.', error);
      cleanupRecordingResources();
    }

    setIsRecording(false);
  }, [cleanupRecordingResources]);

  const toggleRecording = () => {
    if (isAudioSending) {
      return;
    }

    if (isRecording) {
      stopRecording();
    } else {
      void startRecording();
    }
  };

  const handleSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();

    if (!canSubmit || isSubmitting) {
      return;
    }

    setIsSubmitting(true);

    try {
      await Promise.resolve(
        onSendMessage({
          text: message.trim(),
          files: selectedFiles
        })
      );

      setMessage('');
      setSelectedFiles([]);
      if (fileInputRef.current) {
        fileInputRef.current.value = '';
      }
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleReRecord = () => {
    resetAudioState();
    setRecordingError(null);
  };

  const handleSendAudio = async () => {
    const currentPreview = audioPreview;
    if (!currentPreview || isAudioSending) {
      return;
    }

    setIsAudioSending(true);
    setRecordingError(null);

    try {
      await Promise.resolve(
        onSendMessage({
          text: '',
          files: [],
          audio: {
            blob: currentPreview.blob,
            mimeType: currentPreview.mimeType,
            durationMs: currentPreview.durationMs,
            waveform: currentPreview.waveform
          }
        })
      );
      resetAudioState();
    } catch (error) {
      console.error('Audionachricht konnte nicht gesendet werden.', error);
      const messageText =
        error instanceof Error && error.message
          ? error.message
          : 'Audionachricht konnte nicht gesendet werden.';
      setRecordingError(messageText);
    } finally {
      setIsAudioSending(false);
    }
  };

  const handleMessageKeyDown = (event: KeyboardEvent<HTMLTextAreaElement>) => {
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault();
      if (canSubmit && !isSubmitting) {
        event.currentTarget.form?.requestSubmit();
      }
    }
  };

  const isRecordButtonDisabled =
    isAudioSending || (!isRecording && (!pushToTalkEnabled || recordingUnsupported));

  return (
    <form
      onSubmit={handleSubmit}
      className="relative mt-6 rounded-3xl border border-white/10 bg-[#1b1b1b]/80 backdrop-blur-2xl p-4 shadow-[0_0_40px_rgba(190,207,57,0.12)]"
    >
      {(selectedFiles.length > 0 || audioPreview || recordingError || isRecording || recordingUnsupported) && (
        <div className="mb-4 space-y-3">
          {selectedFiles.length > 0 && (
            <div className="flex flex-wrap gap-2">
              {selectedFiles.map((file, index) => (
                <span
                  key={`${file.name}-${index}`}
                  className="inline-flex items-center gap-2 rounded-2xl border border-white/10 bg-white/10 px-3 py-2 text-xs text-white/80"
                >
                  <PaperClipIcon className="h-4 w-4" />
                  <span className="max-w-[160px] truncate" title={file.name}>
                    {file.name}
                  </span>
                  <span className="text-white/40">{formatFileSize(file.size)}</span>
                  <button
                    type="button"
                    onClick={() => handleRemoveFile(index)}
                    className="rounded-full bg-white/10 p-1 text-white/50 transition hover:bg-white/20 hover:text-white"
                    aria-label={`${file.name} entfernen`}
                  >
                    <XMarkIcon className="h-3 w-3" />
                  </button>
                </span>
              ))}
            </div>
          )}

          {isRecording && (
            <div className="space-y-3 rounded-2xl border border-rose-500/40 bg-rose-500/10 p-3 text-xs text-rose-100">
              <div className="flex items-center justify-between">
                <span className="uppercase tracking-[0.2em]">Aufnahme läuft …</span>
                <span className="font-mono text-sm">{formatDuration(recordingDurationMs)}</span>
              </div>
              <div className="flex h-12 items-end gap-1">
                {waveformBars.map((value, index) => (
                  <span
                    // eslint-disable-next-line react/no-array-index-key
                    key={index}
                    className="flex-1 rounded-full bg-rose-200/70"
                    style={{ height: `${Math.max(6, value * 100)}%` }}
                  />
                ))}
              </div>
            </div>
          )}

          {audioPreview && !isRecording && (
            <div className="space-y-3 rounded-2xl border border-white/10 bg-white/5 p-3 text-xs text-white/80">
              <div className="flex items-center justify-between gap-2">
                <div className="flex items-center gap-2">
                  <MicrophoneIcon className="h-4 w-4 text-brand-gold" />
                  <span>Aufgenommene Audionachricht</span>
                  <span className="text-white/50">{formatDuration(audioPreview.durationMs)}</span>
                </div>
                <button
                  type="button"
                  onClick={handleReRecord}
                  className="inline-flex items-center gap-1 rounded-full border border-white/10 px-2 py-1 text-[10px] uppercase tracking-[0.2em] text-white/60 transition hover:bg-white/10"
                >
                  Neu aufnehmen
                </button>
              </div>
              <audio controls src={audioPreview.url} className="w-full" />
              <div className="flex justify-end">
                <button
                  type="button"
                  onClick={handleSendAudio}
                  disabled={isAudioSending}
                  className="inline-flex items-center gap-2 rounded-2xl bg-gradient-to-r from-brand-gold via-brand-deep to-brand-gold px-4 py-2 text-xs font-semibold text-surface-base shadow-glow transition hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-60"
                >
                  {isAudioSending ? (
                    <span className="inline-flex items-center gap-2">
                      <span className="h-4 w-4 animate-spin rounded-full border-2 border-surface-base/80 border-t-transparent" />
                      <span>Senden…</span>
                    </span>
                  ) : (
                    <span className="inline-flex items-center gap-2">
                      <span>Senden</span>
                      <PaperAirplaneIcon className="h-4 w-4" />
                    </span>
                  )}
                </button>
              </div>
            </div>
          )}

          {(recordingError || recordingUnsupported) && (
            <div className="rounded-2xl border border-rose-500/40 bg-rose-500/10 px-3 py-2 text-xs text-rose-200">
              {recordingError ?? 'Audioaufnahme wird von deinem Browser nicht unterstützt.'}
            </div>
          )}
        </div>
      )}

      <div className="flex flex-wrap items-center gap-3">
        <input
          ref={fileInputRef}
          type="file"
          multiple
          onChange={handleFileChange}
          className="hidden"
          disabled={isRecording}
        />
        <button
          type="button"
          onClick={() => fileInputRef.current?.click()}
          className="group rounded-2xl bg-white/5 p-3 text-white/70 transition hover:bg-white/10 disabled:cursor-not-allowed disabled:opacity-50"
          title="Dateien anhängen"
          disabled={isRecording}
        >
          <PaperClipIcon className="h-5 w-5 group-hover:text-white" />
        </button>
        <textarea
          ref={textareaRef}
          name="message"
          value={message}
          onChange={(event) => setMessage(event.target.value)}
          onKeyDown={handleMessageKeyDown}
          placeholder="Nachricht an den Agent eingeben..."
          rows={1}
          className="min-h-0 min-w-0 flex-1 resize-none overflow-y-auto bg-transparent px-2 text-sm leading-6 text-white placeholder:text-white/30 focus:outline-none disabled:cursor-not-allowed disabled:opacity-60"
          disabled={isRecording}
        />
        <button
          type="button"
          onClick={toggleRecording}
          disabled={isRecordButtonDisabled}
          className={`group rounded-2xl p-3 transition ${
            isRecording
              ? 'bg-rose-500/20 text-rose-100'
              : !pushToTalkEnabled || recordingUnsupported
              ? 'cursor-not-allowed bg-white/5 text-white/30'
              : 'bg-white/5 text-white/70 hover:bg-white/10'
          } ${isAudioSending ? 'opacity-60' : ''}`}
          title={
            pushToTalkEnabled
              ? recordingUnsupported
                ? 'Audioaufnahme nicht unterstützt'
                : isRecording
                ? 'Aufnahme stoppen'
                : 'Audionachricht aufnehmen'
              : 'Audioaufnahme deaktiviert'
          }
        >
          <MicrophoneIcon className={`h-5 w-5 ${isRecording ? 'animate-pulse' : ''}`} />
        </button>
        <button
          type="submit"
          disabled={!canSubmit || isSubmitting}
          className="inline-flex items-center gap-2 rounded-2xl bg-gradient-to-r from-brand-gold via-brand-deep to-brand-gold px-5 py-3 text-sm font-semibold text-surface-base shadow-glow transition hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-60"
        >
          {isSubmitting ? 'Sendet…' : 'Senden'}
          <PaperAirplaneIcon className="h-5 w-5" />
        </button>
      </div>
    </form>
  );
}
