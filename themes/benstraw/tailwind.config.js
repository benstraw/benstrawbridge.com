/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["content/**/*.md", "layouts/**/*.html"],
  theme: {
    extend: {
      backgroundImage: {
        'maui-sunset': " url('/images/20231229_172436.jpg')",
      },},
  },
  plugins: [require("@tailwindcss/typography")],
}

