/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./layouts/**/*.html", "./themes/benstraw/layouts/**/*.html"],
  theme: {
    extend: {
      backgroundImage: {
        'maui-sunset': " url('/images/maui-sunset.webp')",
      },},
  },
  plugins: [require("@tailwindcss/typography")],
}

