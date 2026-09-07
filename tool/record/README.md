# Recording X fixtures

> [!INFO]
> Helper to generate test data and get a reference for parsing.

Opens every link in `links.json` with Chrome and saves each GraphQL response to
`test/fixtures/<Operation>/`.

```bash
fvm dart run tool/record/capture.dart
```

## Steps

1. Run the command. Chrome opens with its own profile.
2. Log in when asked. Only the first run asks: the profile is kept in
   `tool/record/.chrome-profile/`. As this runs automatic page loadings, it's
   better to use a throwaway account.
3. Wait. Each page loads, scrolls four times, and every response is written.
4. Review the diff before committing.

## Adding a scenario

One entry in `links.json`:

```json
{ "url": "https://x.com/quax_tests/status/2095920289687150903",
  "description": "Two photos and two videos mixed" }
```

The description lands in the fixture under `scenario`, next to `sourceUrl`.

A profile URL triggers `UserByScreenName` and the profile timeline at once. The
profile views have their own URLs: `/`, `/all`, `/with_replies`, `/reposts`,
`/media`, plus `/highlights` and `?sort=popular`.

## What gets saved

Every GraphQL response, no filter: `queryId`, `features`, `variables`, status,
allow-listed headers, body. Fixtures the run did not reproduce are deleted, so
the directory always matches `links.json` — skipped when a page failed to load.

## Notes

- `tool/record/.chrome-profile/` is gitignored. It holds `auth_token` and `ct0`.
- Responses contain third-party accounts. Check before committing.
- Uses an installed Chrome, or `CHROME_PATH`, or downloads one.
- If X refuses the login, start Chrome yourself and attach to it:

  ```bash
  google-chrome --remote-debugging-port=9222 \
                --user-data-dir=$PWD/tool/record/.chrome-profile
  fvm dart run tool/record/capture.dart --attach
  ```
