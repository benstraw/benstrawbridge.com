// Sends a dedicated `404` event from the not-found page, so missing URLs can be
// found in PostHog without filtering $pageview on the page title.
// Cloudflare serves 404.html at the requested URL (no redirect), so location
// is the missing page. A no-op wherever PostHog isn't loaded (previews, dev).
if (window.posthog && typeof window.posthog.capture === 'function') {
  window.posthog.capture('404', {
    path: window.location.pathname + window.location.search,
    referrer: document.referrer || '$direct',
  });
}
