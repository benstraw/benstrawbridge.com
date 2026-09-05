+++
title = 'Screenshot-a-Day: An Archive, Not an Alarm'
date = 2026-09-05T09:00:00-07:00
hideAsideBar = true
summary = "Uptime monitoring tells you a site is up. It can't tell you when the hero image stopped rendering in Safari. So I built a self-hosted visual history for the sites I'm responsible for."
description = "Uptime monitoring tells you a site is up. It can't tell you when the hero image stopped rendering in Safari. So I built a self-hosted visual history for the sites I'm responsible for."
homeFeatureIcon = "fa-solid fa-camera"
# Render this page's card with the project's own OG artwork wherever it is
# listed. cardType picks layouts/partials/card-image.html (resolved per page by
# utils/card-type.html); cardImage names the resource it draws.
cardType = "-image"
cardImage = "og.png"
cardImageAlt = "The Screenshot-a-Day project card: \"A visual history you own\", beside three stacked browser captures of the same page dated June 04, July 19, and August 17, tagged 0.42% changed"
# Share the project's own card rather than the generated title-on-base-image
# default. get-featured-image.html resolves og_image from the page bundle.
og_image = "og.png"
tags = [
  "open-source",
  "self-hosted",
  "playwright",
  "typescript",
  "arts-link",
  "web-development"
]
+++

A theme update breaks a hero image on Safari. A hosting provider changes a default. A CMS plugin starts injecting something. Nobody notices for six weeks, and when someone finally does, the only honest answer to “when did this start?” is a shrug.

I have given that shrug more than once. This week I shipped [Screenshot-a-Day v0.1.0](https://github.com/arts-link/screenshot-a-day) so I would stop having to.

The idea is not new around here. It has been sitting on this site [as a sketch](/projects/screenshot-a-day/) since May 2024, back when I assumed the answer was a $10/year SaaS running Puppeteer on a Lambda. What actually shipped went the other direction on almost every one of those assumptions, and the reasons are the interesting part.

<!--more-->

It is a self-hosted visual history for websites—a Wayback Machine for the sites you are actually responsible for. It captures on a schedule in Chromium, Firefox, and WebKit, compares any two moments, publishes galleries and GIF/WebM timelines, and never asks you to hand your archive to anyone else.

## Knowing a site is up is not knowing how it changed

I maintain sites for other people. Through Arts-Link I look after work for artists and independent makers, plus a family archive and my own things. The failure mode I kept hitting was never downtime—uptime monitoring solves downtime. It was the quieter kind above: a rendering regression that no probe is watching for, in a browser I don't use daily, discovered long after the commit that caused it.

I now run an instance with the home page of every Arts-Link client site on it, capturing daily. That archive isn't really for me. It is so that when someone asks what their site looked like before the redesign, or whether something has been broken since March, there is an actual answer instead of my recollection.

The two obvious options didn't fit.

**The open-source option: [changedetection.io](https://github.com/dgtlmoon/changedetection.io).** It is the best-known self-hosted tool in this space and it is genuinely good at what it does—watch a page, diff it, fire a notification. But its center of gravity is *detection*: tell me something changed so I can go react. It is built around the current state and the delta from the last check. I wanted the opposite emphasis, a durable browsable archive where comparison is one thing you can do with it rather than the whole point. I also wanted cross-browser captures on the same schedule, which is a rendering question, not a change-detection question.

**The commercial option: [Visualping](https://visualping.io/).** Polished, hosted, low-friction, and the retention and check frequency I'd want live in the upper tiers of a subscription—multiplied by every site I watch, forever. More to the point, it means the visual record of my clients' sites lives in someone else's account, on someone else's retention policy, with headers and cookies for authenticated pages sitting in their vault. For a portfolio site that's a shrug. For work I'm accountable for, it isn't.

So: an archive, not an alarm. Cross-browser. On my hardware. Priced at electricity.

## Ten ADRs before any real code

Fifty-three commits, August 12 to September 5, about 24,000 lines of TypeScript. The history is public, and it is a fairly honest record of the shape of the thing.

The first day laid down the architecture as ten [ADRs](https://github.com/arts-link/screenshot-a-day/tree/main/docs/adr) before there was anything to architect. That sounds heavier than it was—most are four sentences—but writing them first meant the expensive decisions got made deliberately rather than discovered later:

- **Split the control plane and the worker.** The Fastify/React API and the Playwright worker are separate processes. Browsers crash and eat memory; when one does, the settings and history UI stays up.
- **SQLite and local blobs, behind a `BlobStore` interface.** The default install should be one `docker compose up`, not a database tier. The interface is there so Postgres and S3 can arrive later without a rewrite.
- **A leased job protocol.** Workers claim work from the API with a lease, upload artifacts, and report idempotent results. Expired leases are retryable. Workers never touch SQLite or the data volume directly.
- **Captures are Playwright profiles.** A project owns named profiles—bundled Chromium, Firefox, or WebKit, plus viewport and rendering preferences. One run batches every enabled profile, so cross-browser history shares a schedule while failures stay independent.

Then it hit reality, which is where the interesting commits are.

## The security day, and the deletion

**August 17 was a security day.** Six fixes in a row, and they are the ones I'd point a reviewer at: project-scoped API tokens actually enforced, capture headers scoped to the target origin so they don't leak across a redirect, and capture traffic pinned to vetted addresses after DNS resolution.

That last one matters more than it sounds. A tool that fetches arbitrary URLs on your home network is an SSRF boundary even when only you can log in. Loopback, link-local, private, and cloud-metadata destinations are denied by default and require an explicit allowlist.

**August 20 through 23 is my favorite sequence, because it is a deletion.** I built static gallery publishing—render a complete static site locally, push it to Vercel, Netlify, or SFTP—and the first implementation generated a Hugo source tree and shelled out to a pinned Hugo Extended binary with a pinned theme.

It worked. Then I reviewed it before tagging and found that every layout was a project-level override, the only partial was my own analytics snippet, and the templates used `range`, `if`, `with`, `where`, `index`, and `printf`. All the gallery and pagination data was already assembled in TypeScript. Hugo was interpolating strings and nothing else.

The bill for that interpolation: a Hugo binary grafted across a libc boundary into the API image, a third-party theme pinned at a commit, checksummed install steps in CI, an availability probe with its own user-visible failure mode, and a subprocess that inherited the API's entire environment—including the encryption key.

I replaced it with about 200 lines of typed template functions behind the same interface, so the three deploy adapters never noticed. [ADR 0010](https://github.com/arts-link/screenshot-a-day/blob/main/docs/adr/0010-static-publication.md) records the trade I accepted in return: Hugo auto-escaped and my templates don't, so every interpolation goes through one helper, and the renderer test asserts escaping in both element and attribute contexts.

Coming from someone who builds Hugo sites and maintains a Hugo theme, that deletion was not a verdict on Hugo. It was a verdict on running a static site generator as a subprocess to do work the calling process had already done.

## The last two weeks were mostly taste

Splitting each project into focused Compare and Configuration workspaces instead of one settings soup. Real comparison modes—side-by-side, split, overlay, and a pixel heatmap—with keyboard-operable controls. Making the manual capture button admit what it is doing instead of returning instantly and looking broken. Making schedule saves show unmistakably whether the thing is enabled and when it fires next.

Individually small; collectively the difference between a demo and something I'll still be running in a year.

Two things landed late and I'm glad they did. An [experimental MCP endpoint](https://github.com/arts-link/screenshot-a-day/blob/main/docs/api/README.md), so an agent with a scoped bearer token can list projects, inspect capture history, and queue a capture—same permission boundary as the REST API, no side door. And an automated release-evidence run: a guarded backup/restore rehearsal into isolated volumes that records readiness, SQLite integrity, a retained-image digest, and a fresh three-browser batch. If I'm going to tell people to trust their archive to this, I should be able to prove the restore path works, on demand, without deleting the original.

## The combination I couldn't buy

The individual features aren't novel. The combination is the part that wasn't available:

- **Cross-browser captures on one schedule.** Chromium, Firefox, and WebKit as sibling profiles in the same run. Most Safari-only bugs I've chased would have shown up here as a diff.
- **Four ways to compare.** Side-by-side, split, overlay, and heatmap, with SHA-256 hashes and a change percentage, over profile-first history pages.
- **Timelines, not just diffs.** GIF and WebM exports from retained frames. Watching a year of a site in four seconds is a different kind of information than a diff.
- **Three sharing modes.** Private by default. Unlisted via a rotatable token with `noindex`. Indexable via a readable slug. Public routes never serialize target headers, cookies, or worker credentials.
- **Static publication.** The renderer builds the whole site locally and pushes it out, so the capture host needs outbound HTTPS and nothing inbound. This is the one I'd keep if I could keep only one.
- **Encrypted target secrets.** Headers and cookies for authenticated pages are encrypted with an installation-owned AES-256-GCM key and revealed only to an authenticated worker for the active job.
- **Signed webhooks and an MCP endpoint**, so it can tell other systems something changed, or answer an agent that asks.
- **No product telemetry.** The application phones nobody.

It is AGPL-3.0-or-later, distributed as two multi-arch images on GHCR with provenance and SBOM attestations attached to each digest.

## It runs on my hardware, and it stays there

That is the entire point. My instance watches the home page of every Arts-Link client site. The home server holds the archive, the SQLite database, and the encrypted secrets, and it never takes an inbound connection from the public internet. When I want galleries public, the renderer builds a static site locally and pushes it to hosting I already pay for.

[The demo](https://screenshots.arts-link.com/) is exactly that: static output from a private deployment. There is no admin UI, API, or worker behind it, because there is nothing there to reach.

So: is there a hosted service? The 2024 sketch on this site says there should be, with a price on it. Two years later I think that page had the product backwards: the value is a durable archive you control, and a subscription is the one shape that puts an expiry date on it.

Not today, then—and I want to be careful about how I answer that. A multi-tenant version is on the [roadmap](https://github.com/arts-link/screenshot-a-day/blob/main/ROADMAP.md) as a *candidate*, alongside S3-compatible storage, Postgres, and remote worker pools—none of them committed until an issue and an ADR justify the compatibility cost. The self-hosted product is the product. If a service ever exists it will be a convenience for people who don't want to run Docker, not the real version with the free one crippled underneath it. The AGPL is there partly to keep me honest about that.

Screenshot-a-Day is an [Arts-Link](https://github.com/arts-link) project, the same practice the [Ryder theme](https://github.com/arts-link/ryder) comes out of: web services for artists and independent makers, sites that need to outlive their hosting bill, migrations off platforms that are failing or getting expensive, and archives that stay owned by the person who made the work. This tool came directly out of that. If I'm going to promise someone their site will still be there, I should be able to show them what it looked like the whole way along.

## The board is public

The [screenshot-a-day roadmap board](https://github.com/orgs/arts-link/projects/2) has every open item with a Phase, Priority, and Size, in five phases:

1. **Release Quality**—the sharp edges v0.1.0 shipped with, and the ones I care most about right now
2. **Onboarding & Docs**—first-run help, documented project-scoped tokens, screenshots throughout the docs
3. **Foundation**—exact visual identity and shared artifact ownership
4. **Comparison UX**—deep-linkable comparison state, a draggable split handle with synced zoom and pan, overlay and heatmap parity in static galleries
5. **Capture & Scale**—whole-site recurring archives, collapsing identical captures into date ranges, configurable notification routing, checking `robots.txt` before capture

If you want to contribute, the small ones marked `S` in phases 1 and 2 are the honest starting points: feedback flows that fire silently, a dialog that loses input on a backdrop click, first-screen help. They are the kind of thing that is obvious to a new pair of eyes and invisible to me.

The process is short. Open or comment on an issue before a broad architectural change, use Conventional Commits, update tests and docs in the same change, add a Changeset for anything user-visible, and run `pnpm check` before asking for review. Commits need a [DCO 1.1](https://github.com/arts-link/screenshot-a-day/blob/main/CONTRIBUTING.md#developer-certificate-of-origin) sign-off—`git commit --signoff`—and there is no CLA. I'm not asking anyone to assign me their copyright to fix a button.

What I'd most like right now isn't code, though. It is people running it: the deployment path, capture reproducibility, which comparison views actually earn their place, and whether it behaves on ARM hosts and behind your reverse proxy.

A monitor tells you something is wrong now. An archive tells you when it started. I have needed the second one far more often, and until this month I didn't have it.

- Source and releases: [github.com/arts-link/screenshot-a-day](https://github.com/arts-link/screenshot-a-day)
- Live demo: [screenshots.arts-link.com](https://screenshots.arts-link.com/)
- Roadmap board: [github.com/orgs/arts-link/projects/2](https://github.com/orgs/arts-link/projects/2)
