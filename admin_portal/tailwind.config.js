/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,jsx,ts,tsx}'],
  theme: {
    extend: {
      colors: {
        primary: {
          DEFAULT: '#006B5E',
          dark: '#004D43',
          light: '#4DB6A9',
        },
        secondary: '#FFB300',
        mtn: '#FFCC00',
        telecel: '#E31837',
        at: '#003087',
      },
      fontFamily: {
        sans: ['Inter', '-apple-system', 'BlinkMacSystemFont', 'Segoe UI', 'sans-serif'],
      },
    },
  },
  plugins: [],
};
