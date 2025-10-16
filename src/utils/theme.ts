export type ColorScheme = 'light' | 'dark';

export function applyColorScheme(scheme: ColorScheme) {
  if (typeof document === 'undefined') {
    return;
  }

  document.body.classList.remove('theme-light', 'theme-dark');
  document.body.classList.add(scheme === 'light' ? 'theme-light' : 'theme-dark');
  document.documentElement.style.colorScheme = scheme;
}
