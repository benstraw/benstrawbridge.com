const defaultTheme = require("tailwindcss/defaultTheme");

/**
 * Ryder v0.3.0 splits its Tailwind config into a preset carrying theme,
 * darkMode and plugins, with no `content` — content globs resolve from the
 * consuming site's project root, which a theme cannot know. The `theme.extend`
 * keys below merge on top of the preset's.
 */
module.exports = {
  presets: [require("./themes/ryder/tailwind.preset.js")],
  content: [
    "./config/**/*.toml",
    "./themes/ryder/layouts/**/*.html",
    "./layouts/**/*.html",
    "./content/**/*.md",
  ],
  /**
   * The theme's share-buttons partial assembles these class names by
   * interpolation (`resp-sharing-button--{{ $buttonSize }}` and
   * `resp-sharing-button__icon--{{ $icon }}`), so no literal ever appears in a
   * template for Tailwind to find. They live in `@layer components` in the
   * theme's main.css, which Tailwind tree-shakes — without this they are
   * purged. This is what `./hugo_stats.json` in `content` used to cover.
   */
  safelist: [{ pattern: /^resp-sharing-button(--|__icon--)[a-z]+$/ }],
  theme: {
    extend: {
      backgroundImage: {
        "hidden-home": " url('/images/hidden-home-cover.webp')",
        "header-artist-date-one": " url('/images/header-bg/artist-date-one-night.webp')",
        "header-artist-date-two": " url('/images/header-bg/artist-date-two-night.webp')",
        "header-mdr-channel": " url('/images/header-bg/mdr-channel-md.webp')",
        "header-sunset": " url('/images/header-bg/sunset-playa-1.jpg')",
        "header-sunset-italy": " url('/images/header-bg/sunset-italy.webp')",
        "header-sunset-sf-coke": " url('/images/header-bg/sf-sunset-coke-sign.webp')",
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
