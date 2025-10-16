/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        brand: {
          gold: '#FACF39',
          glow: '#fbdb6b',
          deep: '#f9c307'
        },
        surface: {
          base: '#212121',
          elevated: '#2a2a2a'
        },
        neutral: {
          light: '#e6e6e6',
          white: '#ffffff'
        }
      },
      fontFamily: {
        sans: ['\"Inter\"', 'system-ui', 'sans-serif']
      },
      boxShadow: {
        glow: '0 0 30px rgba(250, 207, 57, 0.25)'
      }
    }
  },
  plugins: []
};
