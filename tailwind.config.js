const defaultTheme = require("tailwindcss/defaultTheme");
const typography = require('@tailwindcss/typography');

module.exports = {
  content: [ 
    "./hugo_stats.json",
    "./config/**/*.toml"
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
