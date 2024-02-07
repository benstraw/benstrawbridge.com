/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./layouts/**/*.html",
    "./themes/benstraw/layouts/**/*.html",
    "./themes/ryder-dev/layouts/**/*.html"
  ],
  theme: {
    extend: {
      backgroundImage: {
        'hidden-home': " url('/images/maui-sunset.webp')",
      },},
  },
  plugins: [require("@tailwindcss/typography")],
}

