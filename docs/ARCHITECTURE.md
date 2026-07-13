# Architecture — Serey for Ubuntu Touch

How the app is structured and why. Pairs with [`API_REFERENCE.md`](API_REFERENCE.md).

The app is a **hybrid**: a native Lomiri/QML shell where most sections are native
(reading the Serey API directly) and the creator **Homepage** section embeds the
existing responsive web app in a WebView. Native is required wherever the product
brief needs **offline save, downloads, or the no-algorithm timeline** — a WebView
can do none of those.

---

## 1. Hybrid model — section by section

| Section | Approach | Backed by |
|---|---|---|
| **Homepage** (creator/media directory + each creator's branded site) | 🌐 **WebView** — top-level load of `https://{dns}/` | `general/get-communities`, `community/by-dns` |
| **News / Blog** | 🔧 **Native** | `serey-web/list-by-new \| list-by-trending \| list-by-hot` (+ `?community_id=`), `details-by-permlink-and-author` |
| **Personal Timeline** | 🔧 **Native** (JWT) | `serey-web/list-by-feed-mixed` + `follow/*` |
| **Video** | 🔧 **Native list** + WebView/MediaPlayer player | `video-component/*` |
| **Settings / Login** | 🔧 **Native** | `auth/*`, `accounts/details-by-username` |

**Why a creator Homepage is a WebView, not native:** a creator's "homepage" in
Serey *is already a website* — a community with its own `dns` (e.g.
`netherlands.serey.io`) rendered by `fe-serey-web`. Re-implementing that
multi-tenant site builder natively would be wasted effort, and these pages don't
need offline support.

---

## 2. Regional sources (Serey NL / US / Independent Hub)

A "regional source" is just a **Serey community** identified by `community_id`.
The list endpoints filter by it **server-side and recursively** (a parent
community includes all its child communities).

Verified live IDs (from `general/get-communities`):

| Source | `community_id` | `dns` | Notes |
|---|---|---|---|
| Global | `1` | `serey.io` | everything |
| Serey **Netherlands** | `99` | `netherlands.serey.io` | populated — children incl. `Vrij Nederland` (100), `Voetbal` (101) |
| Serey **United States** | `26` | `us.serey.io` | |
| **Independent Media Hub** | — | — | the `independents` group exists but is **currently empty** (content/setup dependency on Serey's side) |

A **source switcher** in the UI maps the chosen source to:
- native feeds → pass `?community_id=<id>` to the post/video list endpoints;
- the Homepage WebView → load `https://{dns}/`.

> Keep these IDs in one config place (e.g. `qml/Theme/Config.qml`) so the
> Independent Hub id can be dropped in once Serey publishes it.

---

## 3. Auth strategy

- **Native is the source of truth:** login via `POST /auth/login` → JWT stored in
  `Session` (`Qt.labs.settings`), sent as `Authorization: Bearer <token>`.
- **WebView session (optional, later):** the web app's cookie
  `serey_new_jwt_auth_token` is **non-httpOnly**, JSON
  `{username, token, posting_key, user_device_id}`, scoped to `.serey.io`. The
  `token` is the *same* JWT. So a session can be shared by injecting that cookie
  into the WebView before loading a `*.serey.io` page.
- **v1 decision:** keep the embedded Homepage **browse-only** (no session
  bridging). Add cookie injection only if creators need to act while embedded.

---

## 4. Offline strategy

- **Articles:** cache fetched posts in **SQLite** (`Qt.labs.LocalStorage`) — store
  the normalized view-model (see `Mappers.toPost`) keyed by `author/permlink`;
  "save for offline" pins a row, the feed uses cache-first when offline.
- **Videos:** downloadable **only when `platform_type === 'SEREY'`** — the direct
  file is the `video_link` field (`s3.serey.io` / `upload.serey.io` /
  `fsgw.sabay.com`). `YOUTUBE | TIKTOK | FACEBOOK` return embeds only and
  **cannot** be downloaded.
- **Cannot be cached:** anything in the Homepage WebView (web pages, no-store
  headers) and YouTube-hosted videos.

---

## 5. Embedding rules (important)

- The web app sets `X-Frame-Options: SAMEORIGIN` (`server.js:78`) and CSP
  `frame-ancestors 'none'` (`next.config.js:80`). These block **iframes** but
  **not** a top-level WebView navigation. → **Always load a creator site as a
  full WebView page**, never as a cross-origin iframe.
- **Load the community `dns` subdomain directly** (e.g. `netherlands.serey.io`),
  **not bare `serey.io`** — the latter does a geo-redirect 302 (`server.js`).
- AppArmor needs the `webview` policy group — already set in `serey.apparmor`.
- The reusable piece exists today: `qml/components/VideoWebView.qml` (generalize
  to a `WebAppPage.qml` for the Homepage tab).

---

## 6. Phased roadmap

- **P1 — reframe shell:** tabs become **Homepage (WebView directory) · News ·
  Video · Settings**; add the community **source switcher** (real IDs above,
  Hub as placeholder). Native News/Video/Settings already scaffolded.
- **P2 — differentiators:** Personal Timeline (`list-by-feed-mixed`) + follow/
  unfollow; offline articles + `SEREY` video downloads.
- **P3 — future (per brief):** blockchain "permanent storage" publishing (needs
  posting-key signing), Delta Chat, Webshop (Serey marketplace).

---

## 6b. Convergence (adapt, not scale)

Implemented 2026-07-13 per the Lomiri HIG (see
`docs/ubports-other-considerations/01-convergence.md`) after direct founder
feedback that percentage scaling is wrong and panels must adapt per device.

- **`qml/Theme/Adaptive.qml`** (singleton): window size fed by `Main.qml`;
  metrics `isWide` (> 80gu — the toolkit's AdaptivePageLayout collapse point),
  `listPaneWidth` 40gu, `readingMaxWidth` 80gu, `sheetMaxWidth` 50gu,
  `navRailWidth` 9gu.
- **`qml/components/AdaptiveStack.qml`**: per-tab master–detail container that
  mimics the PageStack API (`push/pop/depth/currentPage`) so all existing
  `pageStack.push()` call sites work unchanged. Phone: full-screen pushes
  (unchanged). Wide: root list page in a fixed 40gu left panel, pushes go to a
  right detail panel (a real inner PageStack) with an EmptyState placeholder.
  Crossing the breakpoint is pure geometry — nothing reparents, so live
  WebViews survive window resizes. Homepage opts out (`adaptive: false`).
  We deliberately did **not** migrate to `AdaptivePageLayout`: it has no
  push/pop API, injects back buttons only into `PageHeader`s, and takes over
  headers — it would have broken ~60 call sites and the custom shell.
- **Shell** (`Main.qml`): bottom tab bar becomes a labeled left nav rail on
  wide windows; global header and nav stay visible while a tab is split. The
  bar↔rail switch uses States + AnchorChanges (anchors cannot be conditionally
  reset from a plain binding).
- **Content**: detail/reading columns cap at `readingMaxWidth` centered
  (PostDetail, GalleryDetail, VideoDetail, FeedPage/ProfileView cards);
  composers cap at gu(60); all bottom sheets cap at `sheetMaxWidth` centered;
  ReelsPage centers a gu(45) column on black; VideoDetailPage fullscreen
  reparents its host to `Window.contentItem` to cover the whole window.
  Full-width list rows (Notifications, Downloads, SavedPosts, BlockedUsers)
  intentionally stay full-width — that is the native UT System Settings look.
- **Known follow-ups**: keyboard input parity (focus + MENU key reaching swipe
  actions) and pointer hover states are not yet implemented anywhere.

---

## 7. Open decisions

1. **Independent Media Hub** has no published community yet — confirm with Serey
   when/what `community_id` to use.
2. **Auth bridging** for the embedded Homepage — browse-only for v1 (recommended)
   vs. inject the `.serey.io` cookie.
3. **Homepage tab landing** — a native directory list of communities (from
   `get-communities`) that opens each in a WebView, vs. embedding a single hub
   page directly.

---

## Source references

- Web: `fe-serey-web/server.js:78` (X-Frame-Options), `next.config.js:80` (CSP),
  `src/utils/auth-util.js` (cookie), `src/pages/_app.js` (host→community resolve),
  `src/pages/[community]/index.js` (creator landing), `src/hooks/useIsMobile.js`.
- Backend: `serey-api/src/controllers/general_controller.js:656` (get-communities),
  `src/services/post_service.js:444` (feed-mixed SQL), `src/utils/post_util.js:937`
  (community filter), `src/utils/general_util.js:184` (video platform/URL logic),
  `src/controllers/follow_controller.js`, `src/db/models/serey/community.js`.
