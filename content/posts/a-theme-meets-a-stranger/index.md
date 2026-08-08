+++
title = 'A Theme Meets a Stranger'
date = 2026-08-08T02:19:01-07:00
hideAsideBar = true
summary = "A band's website was the first Ryder site that hadn't grown up alongside the theme, and it turned out to be the best test suite the theme ever had."
description = "A band's website was the first Ryder site that hadn't grown up alongside the theme, and it turned out to be the best test suite the theme ever had."
homeFeatureIcon = "fa-solid fa-dog"
tags = [
  "hugo",
  "ryder-theme",
  "open-source",
  "web-development",
  "testing"
]
+++

I clicked the “Latest release” badge in Ryder’s README and landed on `v0.0.1-alpha`, dated January 2024.

That would have been unremarkable if it were the latest release. It wasn’t. Ryder had shipped `v0.1.0` through `v0.2.4`, but the release workflow marked every automated release as a prerelease. GitHub excludes prereleases from that badge, so two years of releases were present, downloadable, and effectively invisible from the project’s front door.

<!--more-->

Nothing had crashed. The workflow ran, the releases existed, and the badge linked to a valid page. Every component did something reasonable on its own, and together they told a lie.

I only found it because someone else finally had a reason to look. That is the short version of what taking the [Ryder Hugo theme](https://github.com/arts-link/ryder) from `v0.2.3` to [`v0.3.0`](https://github.com/arts-link/ryder/releases/tag/v0.3.0) taught me: a project gets honest the moment a stranger starts using it. Someone who doesn’t already know how it works can’t unconsciously route around the parts that don’t. Everything below came out of that one change in circumstance, and the theme is considerably better for it.

## What made this one different

Ryder started as the theme for this site, and this site is still the most demanding thing it runs. But a theme and a site that grow up together are cooperative. Whenever the site needed something, I changed the theme, and I never had to write down what the contract between them was—I just knew. The example site and the automated tests have the same limitation for the same reason. All of them exercise paths the author already knows exist.

[whatisverdezul.com](https://github.com/arts-link/whatisverdezul.com), a site for a band, was the first Ryder site in a long while, and the first that hadn't grown up alongside the theme. It used Ryder as a pinned Git submodule and then asked the theme to support a real design, real analytics, a real contact form, custom structured data, and a content workflow. Where Ryder had no extension point—or where an extension point did not work—the site accumulated an override.

Reading that site as a defect report produced a [31-item change spec](https://github.com/arts-link/ryder/blob/v0.3.0/docs/specs/v0.3.md). The work shipped in three stages: [`v0.2.4`](https://github.com/arts-link/ryder/releases/tag/v0.2.4) for the most direct defects, [`v0.2.5`](https://github.com/arts-link/ryder/releases/tag/v0.2.5) for extension points and safer primitives, and `v0.3.0` for the breaking changes.

The release notes explain what changed, and the [migration guide](https://github.com/arts-link/ryder/blob/v0.3.0/docs/migration/v0.3.0.md) explains what a consumer should do. What interested me after the upgrade was why so many incorrect states had been able to look correct.

## Correct-looking HTML, dead behavior

The spec began with five theme-caused failures that had reached production. None produced a build error or a console warning. The HTML looked right.

Three of those failures had the same root cause. Ryder uses Alpine’s CSP-compatible build, which deliberately limits what can run inside inline directives. Member calls and arrow functions used in analytics and form handlers were outside the supported expression set at the time. Instead of throwing an obvious error, the handlers simply did not run. A click looked like a click. The contact form looked like a form. The form was never actually functional.

That is a particularly expensive kind of failure because the browser renders the evidence in favor of the code. The button is present, the attributes are present, and the page is otherwise healthy. Unless someone performs the action and verifies its effect, there is no signal to investigate.

The structured data was quieter still. Ryder’s `head/schema.html` emitted comments such as `// homepage` inside `<script type="application/ld+json">`. Those look natural in JavaScript, but JSON does not allow comments. Hugo does not parse the contents of that script element, so every build was green while every affected JSON-LD block was invalid and discarded by parsers.

The immediate `v0.2.4` fix deleted the comments. The structural `v0.3.0` fix stopped hand-writing JSON and instead [built Hugo dictionaries and passed them through `jsonify`](https://github.com/arts-link/ryder/blob/v0.3.0/layouts/partials/head/schema.html). The corresponding browser tests now parse the emitted blocks. That difference matters: removing three bad strings fixes three bad strings; changing the construction method makes the whole class of error harder to express.

The release badge had the same shape. The bug was not “the workflow crashed.” It was a hardcoded `prerelease=true` on the successful path. The [fix](https://github.com/arts-link/ryder/commit/483c7910fdaa15a24e021183b9370fa6d1a94120) derives prerelease status from the version suffix and explicitly marks full releases as latest. The useful assertion is not merely that a release exists. It is that the public pointer people actually follow resolves to it.

## The fixes needed the same scrutiny

The most instructive part came next, when my own corrections turned out to be subject to the same problem. One item in the spec said Hugo consumers inherit the theme’s `[build]` configuration. Based on that assumption, `v0.2.4` moved `writeStats` and the Tailwind cachebuster rules into Ryder.

The change was valid TOML. Ryder’s example site built. Consumers did not inherit the block.

That meant no consumer `hugo_stats.json`, which in turn meant Tailwind could miss classes assembled dynamically in templates. Most classes were still discovered through normal file globs, so a page could look fine while a small set of styles disappeared. The fix intended to detect missing CSS had become another mostly-correct state. Only a build of the actual band site proved the assumption false, and Ryder had to [restore and document the consumer-owned config](https://github.com/arts-link/ryder/commit/0b530c73800f2b89db5101d243ee0cf58c61ce85).

The same mistake appeared again in the breaking-release plan. This time the spec said consumers inherit the theme’s `[outputs]` block and could delete their duplicate. They cannot. Following the instruction would have silently removed `llms.txt` from every upgraded site. Once again, the syntax was valid and the build was green. Once again, a real consumer build—not the theme build—caught it. The final release [documents that `outputFormats` is inherited while `outputs` is not](https://github.com/arts-link/ryder/commit/3b8de2f3c887b11fcab8b27d18b114222daff0c6).

The repetition was useful. I had been treating “theme configuration” as one thing. Hugo treats root configuration sections independently. The correct test was never “does Hugo merge theme config?” It was “does a clean consumer inherit this specific section, and does the expected artifact exist afterward?”

The favicon work provided an even cleaner example of a detector that needed testing. `v0.2.5` added an `appleTouchIcon` parameter. Hugo lower-cases configuration keys, but the template checked `isset $favicon "appleTouchIcon"`. That lookup could never match `appletouchicon`, so the configured value was unreachable by any spelling.

The favicon test passed.

It asserted that the rendered URL contained `apple-touch-icon.png`, which was both the explicit example-site value and the theme fallback. The test could not distinguish “the parameter was honored” from “the parameter was ignored.” The bug surfaced only when I pointed the band site at the release branch and tried to delete its favicon override. The [follow-up fix](https://github.com/arts-link/ryder/commit/2fc28bcfe27b62f466ee31461dfe8d51dea9a69f) uses the lower-cased key and adds a test for a sized-icon array with no default. That test can prove the config was read because there is no fallback path capable of producing the same output.

One final trap appeared while replacing the band site’s blanket `'unsafe-inline'` allowance with a SHA-256 hash for its one inline script. The development CSP still included `'unsafe-inline'`, yet the shows page went dead under `hugo server`.

Per CSP Level 2 and later, a nonce or hash source in `script-src` causes browsers to ignore `'unsafe-inline'`. Emitting a configured production hash in development therefore neutralized the development allowance sitting beside it. Worse, `hugo --minify` changes the exact bytes covered by the hash, so a hash computed from a production build will not necessarily match the unminified development script. Ryder’s final CSP implementation [emits site-configured hashes only in production](https://github.com/arts-link/ryder/blob/v0.3.0/layouts/partials/head/csp.html). A policy cannot be verified by reading the words in the directive; it has to be exercised in the environment where the browser enforces it.

## What started producing reliable signals

By this point the pattern was clear enough to design against: a failure that still produces plausible output can turn up at any layer, including the layers built to catch it. The useful response was not more logging everywhere. It was checks placed at the boundary where an assumption becomes observable.

Variant dispatch now uses `templates.Exists` before calling a partial assembled from a parameter. A typo produces a named warning and a safe fallback instead of a mysterious missing layout. PostHog configuration uses build-time warnings when the provider is enabled but its credentials cannot be read. Bad Open Graph image paths produce a named `errorf` instead of a nil-pointer failure somewhere inside image processing.

For data, the theme constructs values first and serializes them last. The JSON-LD tests call `JSON.parse` on rendered output rather than checking for a few expected strings. For configuration, tests use values that differ from defaults and include negative cases: an item called “Never Rendered” is useful because its accidental appearance proves a conditional failed.

Most importantly, every staged release was tested by upgrading the real consumer. Theme tests answer whether Ryder’s own fixture still works. A consumer test answers whether the contract between two repositories works: config inheritance, submodule pins, root dependencies, overrides, generated artifacts, production CSP, and all.

The last part is verifying the verifier. A green command is evidence only after I can say what it actually exercised: extended or non-extended Hugo, local install or clean lockfile install, development or production, configured value or fallback. “Exit 0” is not a property of the software. It is a property of one command in one environment.

## The deletion list

The upgrade ended with what I now consider the best release metric. Across the three staged upgrades—[`v0.2.4`](https://github.com/arts-link/whatisverdezul.com/pull/12), [`v0.2.5`](https://github.com/arts-link/whatisverdezul.com/pull/13), and [`v0.3.0`](https://github.com/arts-link/whatisverdezul.com/pull/14)—the band site deleted seven categories of workarounds:

- its only `!important` body block;
- a `body:has(...) > div:not(.fixed)` positioning hack;
- an Open Graph image resolver override;
- a favicon override;
- `scriptSrc = "'unsafe-inline'"`, replaced by one SHA-256 hash;
- a full `head/schema.html` override, replaced by a small additive hook;
- and the dead `build-tw`, `watch-tw`, and `deploy-tw` scripts.

The last of those emitted more structured data after deleting its schema override: the custom `MusicGroup` and `MusicAlbum` blocks remained, while Ryder’s `WebPage`, `BlogPosting`, and breadcrumb data returned. The site finished with less code under its control and more correct output.

That is stronger evidence than a feature checklist. A feature list says what a release adds. The deletion list proves what it fixed.
