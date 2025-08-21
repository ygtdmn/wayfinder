/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './index.html',
    './src/**/*.{ts,tsx}',
  ],
  theme: {
    extend: {
      colors: {
        hacker: {
          bg: '#0a0f0a',
          panel: '#0f1410',
          grid: '#0c120c',
          neon: '#39ff14',
          cyan: '#00ffff',
          magenta: '#ff00ff',
          amber: '#ffbf00',
        },
      },
      fontFamily: {
        mono: ['IBM Plex Mono', 'ui-monospace', 'SFMono-Regular', 'Menlo', 'monospace'],
        pixel: ['Press Start 2P', 'monospace'],
      },
      boxShadow: {
        neon: '0 0 10px rgba(57,255,20,0.5), 0 0 20px rgba(57,255,20,0.25)',
      },
    },
  },
  plugins: [],
}

