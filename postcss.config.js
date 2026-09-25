let tailwindConfig = process.env.HUGO_FILE_TAILWIND_CONFIG_JS || './tailwind.config.js';
const tailwind = require('tailwindcss')(tailwindConfig);
const autoprefixer = require('autoprefixer');

// Hugo runs PostCSS under Node's permission model, which only allows reads
// inside the project. Left to itself, browserslist walks up past the repo
// root twice (config via package.json/.browserslistrc, then
// browserslist-stats.json) and the build dies with ERR_ACCESS_DENIED. Passing
// the queries and stats directly skips both lookups. 'defaults' is exactly
// what browserslist fell back to anyway: the repo has no browserslist config.
// Do not add one, or a browserslist key in package.json: it won't be read.
const prefixer = autoprefixer({ overrideBrowserslist: 'defaults', stats: {} });

module.exports = {
	// eslint-disable-next-line no-process-env
	plugins: [tailwind, ...(process.env.HUGO_ENVIRONMENT === 'production' ? [prefixer] : [])],
};
