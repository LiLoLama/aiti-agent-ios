export function TypingIndicator() {
  return (
    <div
      className="inline-flex items-center gap-2 rounded-2xl border border-white/10 bg-white/10 px-4 py-3 text-xs text-white/60 shadow-glow"
      role="status"
      aria-live="polite"
    >
      <span className="sr-only">AITI Agent tippt…</span>
      {[0, 1, 2].map((index) => (
        <span
          key={index}
          className="h-2.5 w-2.5 rounded-full bg-white/70"
          style={{
            animation: 'aiti-bounce 1.2s infinite',
            animationDelay: `${index * 0.15}s`
          }}
        />
      ))}
    </div>
  );
}
