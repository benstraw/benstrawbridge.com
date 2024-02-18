/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["content/**/*.md", "layouts/**/*.html"],
  theme: {
    extend: {
      backgroundImage: {
        "maui-sunset": " url('/images/maui-sunset.webp')",
      },
    },
  },
  plugins: [require("@tailwindcss/typography")],
};
