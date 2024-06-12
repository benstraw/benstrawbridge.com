/** @type {import('tailwindcss').Config} */
const defaultTheme = require("tailwindcss/defaultTheme");

module.exports = {
  // content: ['./hugo_stats.json'],

  content: [
    "./hugo_stats.json",
    "./layouts/**/*.html",
    "./config/**/*.toml",
    "./content/**/*.md",
    "./themes/benstraw/layouts/**/*.html",
    "./themes/ryder/layouts/**/*.html",
    "./themes/ryder-dev/layouts/**/*.html",
  ],
  darkMode: 'class',
  theme: {
    extend: {
      backgroundImage: {
        "hidden-home": " url('/images/hidden-home-cover.webp')",
        "header-artist-date-one": " url('/images/header-bg/artist-date-one-night.webp')",
        "header-artist-date-two": " url('/images/header-bg/artist-date-two-night.webp')",
        "header-mdr-channel": " url('/images/header-bg/mdr-channel-md.webp')",
        "header-sunset": " url('/images/header-bg/sunset-playa-1.jpg')",
        "header-sunset-italy": " url('/images/header-bg/sunset-italy.webp')",
        // "header-sunset-mb": " url('/images/header-bg/sunset-mission-bay.jpg')",
        "header-sunset-mb": " url('/images/header-bg/sunset-mission-bay_hu6f04b8530673b6e2cc009e9b6d51ea4d_1824404_1024x768_resize_q100_h2_box.webp')",
      },
      fontFamily: {
        titillium: ["Titillium Web", ...defaultTheme.fontFamily.sans],
      },
      // screens: {
      //   // 'xs': '475px',
      //   ...defaultTheme.screens,
      //   // '3xl': '1600px',
      // },
      screens: {
        'sm': '640px',
        'md': '768px',
        'lg': '1024px',
        'xl': '1280px',
        '2xl': '1280',
      },
    },
  },
  plugins: [require("@tailwindcss/typography")],
};
