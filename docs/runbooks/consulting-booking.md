# Consulting booking page

**"Book a call" on `/consulting/` is a plain outbound link to a Google Calendar
appointment schedule.** No widget is embedded, so there is no CSP change. Until
`params.consulting.bookingURL` is set, every button falls back to a `mailto:`
link to `params.author.email`, so it never dead-ends.

## Set it up

1. **Create the page.** Google Calendar on the web → Create → Appointment
   schedule. A personal Google account gets one booking page, which is enough.
2. **Settings.** 30-minute calls, Google Meet video conferencing, a buffer
   between appointments, and "check calendars for availability" on.
3. **Booking form.** First name, last name and email are built in. Add:

   | Question | Answers | Required |
   | --- | --- | --- |
   | Which describes you best? | Founder / Company outside tech / Something else | yes |
   | What are you trying to get done? | A few sentences | yes |
   | When are you hoping to start? | Right away / In the next 1–3 months / Just exploring | yes |
   | Budget range | Under $10K / $10–25K / $25–75K / $75K+ / Not sure yet | no |

4. **Wire it up.** Paste the booking page link into `params.consulting.bookingURL`
   in `config/_default/hugo.toml` and redeploy.

## Spam

Email verification for bookings needs a paid Google Workspace plan, which a
personal account doesn't have. If junk bookings show up, switch to an intake
form on the site first, with the calendar link on the thank-you step. That is a
separate change and needs a CSP review for `form-action`
([deployment/csp.md](../deployment/csp.md)).

## Measure

`booking_link_click` in PostHog, broken down by `placement` and `target`
([analytics/posthog.md](../analytics/posthog.md)). `target` is `email` while the
fallback is live, `calendar` once the URL is set.
