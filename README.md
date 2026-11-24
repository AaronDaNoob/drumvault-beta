<div align="center">

# DRUMVAULT

### A home for the sounds behind the next great record.

Discover, preview, publish, and manage drumkits, soundkits, samples, beat packs, vocal presets, and sound effects.

[![Open DrumVault](https://img.shields.io/badge/OPEN%20LIVE%20APP-FF5A1F?style=for-the-badge&logo=vercel&logoColor=white)](https://drumvault-aaron.vercel.app/#/)
[![Supabase](https://img.shields.io/badge/POWERED%20BY-SUPABASE-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)](https://supabase.com/)
[![Vanilla JavaScript](https://img.shields.io/badge/FRONTEND-VANILLA%20JS-F7DF1E?style=for-the-badge&logo=javascript&logoColor=111111)](https://developer.mozilla.org/en-US/docs/Web/JavaScript)

[Explore](#-explore-the-catalog) · [Create](#-creator-workflow) · [Screenshots](#-ui-snapshots) · [Run locally](#-run-it-locally) · [Deploy](#-deployment)

</div>

---

## Jump in

- [What is DrumVault?](#-what-is-drumvault)
- [Catalog and explore](#-explore-the-catalog)
- [Producers and social](#-producers--social)
- [Creator workflow](#-creator-workflow)
- [UI snapshots](#-ui-snapshots)
- [How it works](#-how-it-works)
- [Run it locally](#-run-it-locally)
- [Configure Supabase and Google sign-in](#-configure-supabase--google-sign-in)
- [Upload limits and downloads](#-uploads--downloads)
- [Deploy](#-deployment)

## 🎛 What is DrumVault?

DrumVault is a marketplace and creator toolkit for music producers and sound designers. Listeners can discover and preview sounds, while creators can publish collections, maintain their profiles, and manage the files behind each release.

**Live app:** [drumvault-aaron.vercel.app](https://drumvault-aaron.vercel.app/#/)

<details>
<summary><strong>Explore the catalog</strong></summary>

### Find the right sound

- Filter by **All**, **Soundkit**, **Drumkit**, **Beat Pack**, **Vocal Presets**, **Samples**, **SFX**, **Free**, or **Paid**.
- Search catalog items by title and producer.
- Sort by **Newest** or **Most downloaded**.
- The section heading follows the active filter, such as **All Sounds**, **Beat Packs**, or **Free Sounds**.
- Cards surface artwork, producer, likes, downloads, and price.
- Open a kit for its description, contents, demos, likes, sharing, and download actions.
- Preview public demos without signing in. Sign-in is required to download archives.

**Snapshot slot — Explore feed**

> Add `docs/screenshots/explore.png` to show the full catalog, active filter, sorting control, and responsive card grid.

```md
![DrumVault Explore feed](./docs/screenshots/explore.png)
```

**Snapshot slot — Soundkit cards and detail page**

> Add `docs/screenshots/kit-detail.png` to show artwork, producer attribution, price, demo playback, and the Download Kit / Like / Copy link actions.

```md
![Soundkit details and actions](./docs/screenshots/kit-detail.png)
```

</details>

<details>
<summary><strong>Discover producers and connect</strong></summary>

### Producers directory

- Browse producer profiles, handles, biographies, and published kits.
- Compare follower, following, kit, download, and like stats.
- Follow and unfollow producers while signed in.
- Sign in through Google using Supabase Auth.
- Crop and reposition profile pictures before saving.

**Snapshot slot — Producers directory**

> Add `docs/screenshots/producers.png` to show producer cards, profile stats, and follow controls.

```md
![DrumVault Producers directory](./docs/screenshots/producers.png)
```

**Snapshot slot — Profile picture cropper**

> Add `docs/screenshots/profile-cropper.png` to show the crop, reposition, and zoom experience.

```md
![Profile picture cropper](./docs/screenshots/profile-cropper.png)
```

</details>

<details>
<summary><strong>Creator workflow and kit management</strong></summary>

### Creator dashboard

- Review your published kits, download totals, and likes.
- Preview how a kit appears to listeners, including its demo tracks.
- Change kit visibility between **Public** and **Hidden**.
- Edit title, description, type, price, license, visibility, cover art, and archive.
- Rename, add, and remove demo tracks.
- Delete a kit and its associated Storage objects.

> Visibility labels shown in the UI depend on the current app version; the database currently supports public and private kits.

**Snapshot slot — Creator dashboard**

> Add `docs/screenshots/dashboard.png` to show kit management, stats, visibility, and actions.

```md
![Creator dashboard](./docs/screenshots/dashboard.png)
```

**Snapshot slot — Edit soundkit modal**

> Add `docs/screenshots/edit-soundkit.png` to show metadata, visibility, archive replacement, and demo-track controls.

```md
![Edit soundkit](./docs/screenshots/edit-soundkit.png)
```

</details>

## 🖼 UI snapshots

The paths below are placeholders until screenshots are added. Save captures under `docs/screenshots/` and use the filenames in this gallery.

| View | Screenshot | What to capture |
|---|---|---|
| Explore feed | `./docs/screenshots/explore.png` | Hero, filter pills, sorting, and catalog cards |
| Soundkit cards and detail | `./docs/screenshots/kit-detail.png` | Art, likes/downloads, preview, and detail actions |
| Producers directory | `./docs/screenshots/producers.png` | Producer profiles, stats, and follow controls |
| Profile cropper | `./docs/screenshots/profile-cropper.png` | Picture framing and zoom controls |
| Creator dashboard | `./docs/screenshots/dashboard.png` | Creator stats, kit list, visibility controls |
| Edit soundkit modal | `./docs/screenshots/edit-soundkit.png` | Metadata and file-management workflow |

## 🧩 How it works

<details>
<summary><strong>Architecture at a glance</strong></summary>

| Layer | Responsibility |
|---|---|
| `public/index.html` | Single-page UI, hash routing, catalog, auth client, upload/download flows, playback |
| Supabase Auth | Google OAuth and persisted user sessions |
| Supabase Database | Producer profiles, kit metadata, likes, follows, and download records |
| Supabase Storage | Cover artwork, audio demos, private ZIP archives |
| Vercel | Hosts the static production frontend |
| GitHub Pages | Alternate static deployment from the `gh-pages` branch |

The browser accesses Supabase using the project URL and publishable/anon key. Row Level Security and Storage policies enforce ownership and public/private access. Private archives are downloaded through short-lived signed URLs after the app verifies kit visibility and authentication.

</details>

## 🚀 Run it locally

```bash
git clone https://github.com/AaronDaNoob/drumvault-beta.git
cd drumvault-beta
npm run dev
```

Open [http://localhost:3000](http://localhost:3000). This is a static frontend; no compilation step is required.

### Project layout

```text
public/index.html       App UI and client-side application
supabase-schema.sql     Database, RLS, RPC, and Storage policies
vercel.json             Vercel routing configuration
package.json            Local static-server commands
```

## 🔐 Configure Supabase & Google sign-in

<details>
<summary><strong>Authentication and Storage setup</strong></summary>

1. Create the `covers` (public), `demos`, and `archives` (private) Storage buckets.
2. Run [`supabase-schema.sql`](./supabase-schema.sql) in the Supabase SQL Editor.
3. In Google Cloud, create a Web OAuth client and add the Supabase callback:

   ```text
   https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback
   ```

4. Enable **Authentication → Providers → Google** in Supabase.
5. Set the Supabase Site URL to `https://drumvault-aaron.vercel.app/`.
6. Add deployed and local origins under **Authentication → URL Configuration → Redirect URLs**:

   ```text
   https://drumvault-aaron.vercel.app/
   https://drumvault-aaron.vercel.app/index.html
   https://aarondanoob.github.io/drumvault-beta/
   https://aarondanoob.github.io/drumvault-beta/index.html
   http://localhost:3000/
   http://localhost:3000/index.html
   ```

The app redirects OAuth back to the active site origin. The Supabase project URL and publishable/anon key are configured in `public/index.html`. Never put a service-role key or Google client secret in browser code.

</details>

## 📦 Uploads & downloads

- Cover art: PNG, JPEG, or WebP; up to 5 MB.
- Demo audio: up to 3 MP3/WAV tracks; up to 25 MB per track.
- ZIP archive: app limit currently **50 MB per file**; the Supabase project’s global and bucket limits may be lower.
- Public demo previews are available without sign-in.
- ZIP downloads require sign-in and public kit visibility; archives remain in private Storage.
- Paid prices are metadata only; purchase and entitlement processing are not implemented.

## 🚢 Deployment

### Vercel

The `main` branch is connected to Vercel. To deploy manually:

```bash
npx vercel login
npx vercel --prod
```

Live site: [https://drumvault-aaron.vercel.app/#/](https://drumvault-aaron.vercel.app/#/)

### GitHub Pages

The alternate static deployment is [https://aarondanoob.github.io/drumvault-beta/](https://aarondanoob.github.io/drumvault-beta/), served from `gh-pages`.

## ✅ Release checklist

- [ ] Run the latest Supabase schema in the production project
- [ ] Confirm all three Storage buckets and their access levels
- [ ] Test Google sign-in from a separate device
- [ ] Upload a small kit with cover, demo, and ZIP
- [ ] Verify category filtering and both catalog sort modes
- [ ] Preview public demos while signed out
- [ ] Download a public ZIP while signed in
- [ ] Check that likes, follows, and download counts update
- [ ] Test hiding, republishing, editing, and deleting a kit

## ⚠️ Current limitations

- Checkout and paid-kit download entitlements are not implemented.
- ZIP archives are not scanned for malicious contents or decompression bombs.
- Uploads are direct browser-to-Storage transfers, not resumable multipart uploads.
- Capacity and maximum upload size depend on the Supabase plan and Storage configuration.

---

<div align="center">

Built for the people who make the sounds.

**[Open DrumVault →](https://drumvault-aaron.vercel.app/#/)**

</div>
