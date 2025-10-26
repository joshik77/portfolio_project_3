/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        dark: {
          bg: '#121217',
          card: '#1e1e24',
          border: '#2a2a30',
        }
      },
    },
  },
  plugins: [],
}