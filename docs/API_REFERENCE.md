# API Reference — Serey for Ubuntu Touch

App-focused subset of the Serey v2 API. Pairs with [`ARCHITECTURE.md`](ARCHITECTURE.md).

- **Base URL:** `https://global-api.serey.io/api/v2` (prod) — see `qml/Theme/Config.qml`.
- **Auth:** JWT. Authenticated calls send `Authorization: Bearer <token>`.
  Token ~24h, no refresh endpoint → re-login on 401.
- **Pagination:** `?limit=&offset=` (limit default 10, max 50).
- All client calls go through `qml/services/Http.js`; raw JSON is normalized in
  `qml/services/Mappers.js`.

> **Response quirks (handled in `Mappers.js`):**
> 1. Logical failures return **HTTP 200** with `{"status": false, "message": ...}` — treat `status:false` as an error.
> 2. Several list fields are **stringified Python lists**: `image_url="['https://…']"`, `categories="['general']"`, and `"None"` for null. `serey_value` is a string like `"1685.653 SEREY"`.

---

## Auth

| Method · Path | Auth | Key params | Key response |
|---|---|---|---|
| `POST /auth/login` | — | body `{username, password}` | `data.token`, `data.user_device_id` |
| `POST /auth/authenticated` | JWT | — | `account{...}` (validates token) |
| `DELETE /auth/logout` | JWT | — | `message` |
| `POST /auth/social-login` | — | `{auth_type, social_token}` | `data.token` |

## Feeds / Posts (News + Blog)

| Method · Path | Auth | Key params | Key response fields |
|---|---|---|---|
| `GET /serey-web/list-by-trending` | opt | `limit, offset, community_id?, category?` | `posts[]` |
| `GET /serey-web/list-by-hot` | opt | `limit, offset, community_id?` | `posts[]` |
| `GET /serey-web/list-by-new` | opt | `limit, offset, community_id?` | `posts[]` |
| `GET /serey-web/list-by-author` | opt | `author, limit, offset, community_id?` | `posts[]` |
| `GET /serey-web/list-by-feed-mixed` | **JWT** | `limit, offset` | `posts[]` — **Personal Timeline** (followed authors + subscribed communities) |
| `GET /serey-web/details-by-permlink-and-author` | opt | `author, permlink` | `content{...}`, `replies[]` |

**Post fields:** `id, author, permlink, title, description` (HTML body),
`short_desc, image_url` (stringified list), `author_image_url, publish_date,
voter_count, answer_count` (comments), `serey_value` (payout string),
`categories, community_id, community_title, checkmark_icon, type`.

> `?community_id=` filters **server-side and recursively** (parent includes child
> communities). Verified: `list-by-new?community_id=99` → only Netherlands posts.

## Communities (regional sources + creator homepages)

| Method · Path | Auth | Key params | Key response |
|---|---|---|---|
| `GET /general/get-communities` | — | `country_name?, app_name?` | `{globals[], locals[], foreigns[], independents[]}` |
| `GET /community/by-dns` | — | `dns` (e.g. `netherlands.serey.io`) | community by host |
| `GET /community/list-by-parent-id/:id` | — | — | child communities |
| `GET /custom-menu/list-by-website-and-community` | — | `website, community_id` | homepage menu/site config |

**Community fields:** `id, title, dns, custom_domain, icon_url, logo_url, country,
parent_id, level, is_independent, is_superhub, video_layout`.
**Known IDs:** Global `1`, Netherlands `99` (`netherlands.serey.io`), US `26`
(`us.serey.io`). `independents` group currently empty.

## Follow (for Personal Timeline)

| Method · Path | Auth | Key params | Key response |
|---|---|---|---|
| `GET /follow/list-all-followings` | JWT | — | who I follow |
| `GET /follow/list-followings` | — | `username` | followings of a user |
| `GET /follow/list-followers` | — | `username` | followers of a user |
| `GET /follow/status` | — | `username, author` | is following? |
| `POST /follow/follow-or-unfollow` | JWT | `{author, action_type}` | toggle |

## Video

| Method · Path | Auth | Key params | Key response |
|---|---|---|---|
| `GET /video-component/` | opt | `community_id?, type?, limit, offset` | `data[]` |
| `GET /video-component/list-all-videos-by-author` | opt | `author?, limit, offset` | `data[]` |
| `GET /video-component/list-by-recommended` | — | `community_id?, limit` | `data[]` |
| `GET /video-component/detail-video-post` | — | `author, permlink` | `post{...}` |

**Video fields:** `id, username, permlink, title, description, thumbnail_url,
embed_video, video_link, video_id, platform_type` (`YOUTUBE|TIKTOK|FACEBOOK|SEREY`),
`dimensions, publish_date, voter_count, community_title`.

> **Offline downloadable only when `platform_type === 'SEREY'`** — `video_link`
> is then a direct file (`s3.serey.io` / `upload.serey.io` / `fsgw.sabay.com`).
> Other platforms give embeds (`embed_video`) only.

## Podcast

| Method · Path | Auth | Key params | Key response |
|---|---|---|---|
| `GET /podcast/list` | — | `community_id?, search?, tag?, page, limit` | `data[]` |
| `GET /podcast/get-by-id/:id` | — | — | `data{...}` |
| `GET /podcast/get-by-slug/:slug` | — | — | `data{...}` |

**Podcast media field is `content_url`** (not `audio_url`), with `is_video,
content_type, thumbnail_url, duration, episode_number, season_number`.

## Profile / Account

| Method · Path | Auth | Key params | Key response |
|---|---|---|---|
| `GET /accounts/details-by-username/:username` | — | — | `account{...}` |
| `POST /accounts/update-user-detail` | JWT | profile fields | `message` |
| `GET /accounts/search-user` | — | `username` | `data[]` |

**Account fields:** `full_name, name, bio, reputation, post_count, comment_count,
followers_count, following_count, balance, sereypower, join_date, profile_url,
cover_image_url, checkmark_icon, email, phone, referral_code`.

## Notifications / Bookmarks

| Method · Path | Auth | Key params | Notes |
|---|---|---|---|
| `GET /notification/unread-count-for-serey` | JWT | — | badge count |
| `GET /notification/list-by-current-user-for-serey` | JWT | `limit, offset` | list |
| `PUT /notification/update-read-all-for-serey` | JWT | — | mark read |
| `POST /marketplace/submit-favourite` | JWT | `{author, permlink}` | **only** bookmark mechanism (marketplace module) |
| `GET /marketplace/list-favourite-by-author` | — | `author` | bookmarked list |

---

## Backend source references

`serey-api/src/`: `routes/auth_route.js`, `routes/post_route.js` (+ `:172`
feed-mixed), `controllers/general_controller.js:656` (get-communities),
`services/post_service.js:444` (feed SQL), `utils/post_util.js:937` (community
filter), `utils/general_util.js:184` (video platform/URL logic),
`controllers/follow_controller.js`, `db/models/serey/community.js`,
`db/models/serey/youtube_component.js`, `db/models/serey/podcast.js`.
