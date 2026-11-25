<div align="center">

# DrumVault

**A focused home for producer-made sounds.**

Discover and preview drumkits, soundkits, samples, beat packs, vocal presets, and SFX. Publish your own releases, manage your profile, and share sounds with your community.

[Open the live app](https://drumvault-aaron.vercel.app/#/) · [View the repository](https://github.com/AaronDaNoob/drumvault-beta)

</div>

---

## At a glance

| Explore | Create | Connect |
|---|---|---|
| Search and filter releases by type, price, and popularity | Upload covers, demos, metadata, and ZIP archives | Sign in with Google, follow producers, and like kits |
| Preview audio before downloading | Edit, hide, publish, or delete your kits | Share producer profiles and kit pages |

## What makes DrumVault useful?

DrumVault is designed around a simple workflow: find a sound, hear it quickly, and give producers control over their catalog.

- Catalog filters for **All**, **Soundkit**, **Drumkit**, **Beat Pack**, **Vocal Presets**, **Samples**, **SFX**, **Free**, and **Paid**
- Search across kit titles and producers
- Sort by newest releases or most downloaded kits
- Live category counts and filter-aware section headings
- Persistent audio player with playback controls, seeking, volume, and track navigation
- Public demo previews without requiring sign-in
- Authenticated downloads for free public packs
- Paid-pack state shown clearly while purchase support is not yet enabled
- Google authentication through Supabase
- Producer profiles with social links, avatars, follows, likes, and activity
- Creator dashboard with visibility controls, archive storage usage, and kit management
- Draft, public, and hidden kit workflows
- Upload draft autosave and recovery after refresh
- Lazy-loaded images with async decoding for faster catalog rendering
- Offline/online status feedback and throttled runtime error toasts
- Keyboard shortcuts: `/` focuses search and Space toggles the persistent player
- Cover-art cropping, preview states, and cache-safe artwork replacement

## Interface snapshots

Add screenshots to `docs/screenshots/` using the filenames below. The layout is ready for a polished GitHub project page.

| Screen | Image | Description |
|---|---|---|
| Explore feed | `./docs/screenshots/explore.png` | Catalog hero, filters, counts, sorting, and cards |
| Kit detail | `./docs/screenshots/kit-detail.png` | Artwork, demos, pricing, likes, and actions |
| Producers | `./docs/screenshots/producers.png` | Producer directory, stats, and follow controls |
| Dashboard | `./docs/screenshots/dashboard.png` | Storage usage, kit management, and visibility |
| Edit kit | `./docs/screenshots/edit-kit.png` | Metadata, archive, cover, and demo-track editing |
| Profile cropper | `./docs/screenshots/profile-cropper.png` | Avatar crop and reposition workflow |

```md
![Explore feed](./docs/screenshots/explore.png)
```

<details>
<summary><strong>Explore feed details</strong></summary>

The Explore page is the main catalog view. It includes:

- Search by sound, kit, or producer
- Filter pills with live result counts
- Newest and most-downloaded sorting
- Responsive cards with artwork, producer, likes, downloads, and pricing
- Dynamic headings such as `All Sounds`, `Beat Packs`, and `Free Sounds`

</details>

<details>
<summary><strong>Creator workflow</strong></summary>

Producers can:

1. Sign in with Google.
2. Complete their producer profile.
3. Upload a cover, demo tracks, and ZIP archive.
4. Choose a release type, price, license, and visibility.
5. Publish the kit or save it as a draft.
6. Edit metadata, replace files, rename demos, or remove demos.
7. Monitor archive storage usage and download counts from the dashboard.

</details>

<details>
<summary><strong>Architecture</strong></summary>

```text
public/index.html       Static single-page frontend and client-side routing
supabase-schema.sql     Database tables, RLS policies, RPCs, and Storage policies
vercel.json             Vercel static routing
package.json            Local development scripts
```

| Service | Responsibility |
|---|---|
| Vercel | Production hosting for the frontend |
| Supabase Auth | Google login and session persistence |
| Supabase Database | Profiles, kits, demo tracks, likes, follows, downloads, notifications |
| Supabase Storage | Covers, previews, and private ZIP archives |
| GitHub Pages | Alternate static deployment from `gh-pages` |

The frontend uses the Supabase project URL and publishable/anon key. Never place a service-role key or OAuth client secret in browser code.

</details>

## Run locally

```bash
git clone https://github.com/AaronDaNoob/drumvault-beta.git
cd drumvault-beta
npm run dev
```

Open [http://localhost:3000](http://localhost:3000). DrumVault is a static frontend and does not require a build step.

## Supabase setup

Create these Storage buckets:

| Bucket | Visibility | Purpose |
|---|---|---|
| `covers` | Public | Kit covers and profile avatars |
| `demos` | Private | Audio previews |
| `archives` | Private | Downloadable ZIP files |

Run the complete [`supabase-schema.sql`](./supabase-schema.sql) in the Supabase SQL Editor. The schema configures tables, row-level security, Storage policies, demo deletion permissions, kit visibility, likes, follows, and download RPCs.

### Google OAuth redirect URLs

Enable Google under Supabase Authentication, then configure these redirect URLs as needed:

```text
https://drumvault-aaron.vercel.app/
https://drumvault-aaron.vercel.app/index.html
https://aarondanoob.github.io/drumvault-beta/
https://aarondanoob.github.io/drumvault-beta/index.html
http://localhost:3000/
http://localhost:3000/index.html
```

Google Cloud should use the Supabase callback URL:

```text
https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback
```

## Upload and download limits

Current client-side limits:

- Cover art: PNG, JPEG, or WebP up to 5 MB
- Demo audio: up to 3 MP3/WAV files, 25 MB each
- ZIP archive: 50 MB per file on the current configuration
- Public previews: available without sign-in
- Free ZIP downloads: require Google sign-in
- Paid packs: download is disabled until purchase support is implemented

The effective limit is also controlled by Supabase Storage settings and the project plan. Storage capacity, egress, database size, and monthly active users should be monitored before expanding the community.

## Deployment

### Vercel

The `main` branch is connected to Vercel:

```bash
npx vercel login
npx vercel --prod
```

Production URL: [drumvault-aaron.vercel.app](https://drumvault-aaron.vercel.app/#/)

### GitHub Pages

The alternate deployment is available at [aarondanoob.github.io/drumvault-beta](https://aarondanoob.github.io/drumvault-beta/), served from the `gh-pages` branch.

## Release checklist

- [ ] Run the latest Supabase schema
- [ ] Confirm Storage buckets and policies
- [ ] Test Google login on another device
- [ ] Upload a small free kit
- [ ] Preview demos while signed out
- [ ] Download the free kit while signed in
- [ ] Test paid-pack download blocking
- [ ] Test editing, deleting, hiding, drafting, and republishing
- [ ] Confirm category filters, counts, and sorting
- [ ] Check dashboard storage usage
- [ ] Add screenshots under `docs/screenshots/`
- [ ] Verify Supabase storage and egress usage

## Known limitations

- Paid checkout and purchase entitlements are not implemented.
- Large uploads use direct browser-to-Storage transfer rather than resumable multipart uploads.
- ZIP uploads receive client-side structure, path-traversal, entry-count, and decompression-ratio checks, but are not malware-scanned. Client-side checks can be bypassed; add trusted server-side scanning before accepting untrusted public uploads.
- Production error monitoring, analytics, and rate limiting still need to be added for a larger public launch.

---

<div align="center">

Built for producers who care about the sounds behind the track.

[Open DrumVault](https://drumvault-aaron.vercel.app/#/)

</div>
