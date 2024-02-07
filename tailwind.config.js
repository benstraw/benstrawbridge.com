/** @type {import('tailwindcss').Config} */
const defaultTheme = require('tailwindcss/defaultTheme');

module.exports = {
  content: [
    "./layouts/**/*.html",
    "./config/**/*.toml",
    "./content/**/*.md",
    // "./themes/benstraw/layouts/**/*.html",
    "./themes/ryder/layouts/**/*.html",
    "./themes/ryder-dev/layouts/**/*.html"
  ],
  theme: {
    extend: {
      backgroundImage: {
        'hidden-home': " url('/images/maui-sunset.webp')",
      },
      fontFamily: {
        'titillium': ['Titillium Web', ...defaultTheme.fontFamily.sans],
      },
    },
  },
  plugins: [require("@tailwindcss/typography")],
}

