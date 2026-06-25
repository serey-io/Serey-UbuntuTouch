# Serey for Ubuntu Touch

A native **Ubuntu Touch 24.04 (Lomiri / QML)** client for the [Serey](https://serey.io)
network. It reuses the existing production backend (`serey-api`) and provides
four sections — **Home**, **Blog**, **Video** and **Settings** — wired end-to-end
to the live API, including login and persisted authentication.

This is the first milestone scaffold; more sections (gallery, drum, wallet, …)
will follow.

---

## Requirements

- [Clickable](https://clickable-ut.dev/) **≥ 8.4.0** (8.8.0+ recommended) — the build tool for Ubuntu Touch apps
- Docker (Clickable runs the build inside a container)
- For on-device testing: an Ubuntu Touch device on **24.04-1.x** with developer mode enabled

Install Clickable:

```bash
pipx install clickable-ut    # or: pip install --user clickable-ut
```

## Build & run

From the project root:

```bash
# Fastest feedback loop — run the QML on your desktop via the 24.04 container.
clickable desktop

# Build, install and launch on a connected device.
clickable

# Just build a .click package (no install).
clickable build

# View runtime logs (useful for AppArmor denials or QML errors).
clickable logs
```

> The app targets the `ubuntu-touch-24.04-1.x` framework and **will not install on
> 20.04 devices**.

## Backend configuration

By default the app talks to production: `https://global-api.serey.io/api/v2`.

To point at a local `serey-api` instead, flip the switch in **Settings →
Preferences → "Use local dev server"** (or change `useLocalDev`/the URLs in
[`qml/Theme/Config.qml`](qml/Theme/Config.qml)).

> A **physical device cannot reach `localhost`**. To use the local dev server on a
> device, forward the port over ADB, e.g. `adb reverse tcp:5050 tcp:5050`, or set
> the dev URL to your machine's LAN IP.

---

## Architecture

```
qml/
├── Main.qml              Bottom tab bar + one PageStack per tab; validates a
│                         stored token on launch.
├── Theme/                Singletons (qmldir):
│   ├── Config.qml          API base URL, page size, prod/dev switch.
│   └── Style.qml           Colours, spacing, sizing tokens.
├── Session/
│   └── Session.qml       Singleton: JWT + username, persisted via Qt.labs.settings.
├── services/             Plain-JS API layer (XMLHttpRequest, no C++):
│   ├── Http.js             GET/POST/DELETE helper, Bearer header, error handling.
│   ├── PostService.js      Feed + post detail endpoints.
│   ├── VideoService.js     Video endpoints.
│   ├── AccountService.js   Login / verify / logout / profile.
│   └── Mappers.js          Normalises raw API JSON → stable view-models.
├── components/           Reusable UI: PostCard, VideoCard, SectionTabs,
│                         LoadingState, EmptyState, ErrorState, VideoWebView.
└── pages/                HomePage, BlogPage, VideoPage, SettingsPage,
                          LoginPage, PostDetailPage, VideoDetailPage.
```

**Why a mapper layer?** The Serey API returns several fields as Python-style
*stringified* lists (e.g. `image_url = "['https://…']"`, `categories = "['general']"`)
and uses `"None"` for nulls. `Mappers.js` is the single place that parses these
quirks, so the QML always works with clean objects (`title`, `body`, `thumbnail`,
`votes`, `comments`, `payout`, …).

### API endpoints used (base `…/api/v2`)

| Feature       | Endpoint |
|---------------|----------|
| Home feed     | `GET /serey-web/list-by-trending`, `/list-by-hot`, `/list-by-new` |
| Blog          | `GET /serey-web/list-by-new` |
| Post detail   | `GET /serey-web/details-by-permlink-and-author?author=&permlink=` |
| Videos        | `GET /video-component/list-all-videos-by-author` |
| Login         | `POST /auth/login` → `{ data: { token } }` |
| Verify token  | `POST /auth/authenticated` |
| Logout        | `DELETE /auth/logout` |
| Profile       | `GET /accounts/details-by-username/:username` |

Lists are paginated with `?limit=&offset=` only. **Note:** sending `community_id`
to the list endpoints is rejected (`Invalid parameter`), so it is not used.

Authenticated calls send `Authorization: Bearer <token>`. Tokens last ~24h with
no refresh endpoint; on a 401 the user re-logs in.

---

## Testing checklist

Run `clickable desktop`, then verify:

1. **Home** loads Trending posts; the Trending/Hot/New chips switch feeds;
   scrolling to the bottom loads more (infinite scroll).
2. Tapping a post opens **Post detail** with the full rich-text body.
3. **Blog** lists newest articles; **Video** lists videos.
4. Tapping a video opens **Video detail**; the play button embeds the video
   (WebView), with an "Open in browser" fallback in the header.
5. **Settings → Log in** with a real Serey account succeeds; the profile
   (name, balance, post/follower counts) appears.
6. Relaunch the app — you remain logged in (token persisted). **Log out** clears it.
7. `clickable logs` shows no AppArmor `networking` denials.

To confirm the live API contract independently:

```bash
curl "https://global-api.serey.io/api/v2/serey-web/list-by-trending?limit=2&offset=0"
curl "https://global-api.serey.io/api/v2/video-component/list-all-videos-by-author?limit=2&offset=0"
```

---

## Known limitations / next steps

- **Read-only:** creating/commenting/voting is not implemented (auth is read-only
  for now — Serey write actions require blockchain posting keys).
- Dark mode uses fixed light-theme colours in `Style.qml`; wiring to
  `theme.palette` is a follow-up.
- Video playback relies on the `embed_video` URL via an in-app WebView; direct
  (non-YouTube) media could later use a native MediaPlayer.
- Gallery, drum, wallet sections and a branded icon are future work.

## Project layout note

The `serey.apparmor`, `serey.desktop`, `manifest.json.in` and `clickable.yaml`
identify the app as `serey.tehenglay`. Update the namespace/maintainer fields in
`manifest.json.in` before publishing to the OpenStore.
