# DrumVault

> A focused marketplace for discovering, previewing, publishing, and downloading producer-made soundkits.

[![Live site](https://img.shields.io/badge/live%20site-drumvault--aaron.vercel.app-ff5a1f?style=flat-square)](https://drumvault-aaron.vercel.app/)
[![Built with Supabase](https://img.shields.io/badge/backend-Supabase-3ecf8e?style=flat-square)](https://supabase.com/)

## Explore DrumVault

**Live app:** [drumvault-aaron.vercel.app](https://drumvault-aaron.vercel.app/)

DrumVault gives producers a simple place to publish soundkits and gives artists a fast way to browse, preview, and securely download them.

### What you can do

- Browse a public catalog of soundkits
- Search by kit title or producer
- Filter by kit type and free/paid metadata
- Preview uploaded demo tracks with a persistent audio player
- Sign in with Google through Supabase Auth
- Create and edit a producer profile
- Upload cover art, demos, and private ZIP archives
- Publish or hide kits from the creator dashboard
- Like kits and follow producers
- Download public archives through authenticated, signed Storage URLs
- Use responsive layouts and dark mode on desktop or mobile

## Quick start

```bash
git clone https://github.com/AaronDaNoob/drumvault-beta.git
cd drumvault-beta
npm run dev
```

Open [http://localhost:3000](http://localhost:3000).

The frontend is a static application served from `public/`. There is no build step.

## Project map

```text
public/index.html       Single-page frontend, routing, UI, auth, uploads, playback
supabase-schema.sql     Tables, RLS policies, RPC functions, and Storage policies
vercel.json             Static Vercel routing
package.json            Local development scripts
```

## Supabase setup

Create these Storage buckets before testing uploads:

| Bucket | Visibility | Used for |
|---|---|---|
| `covers` | Public | Cover artwork and profile avatars |
| `demos` | Private | Audio previews |
| `archives` | Private | Downloadable ZIP archives |

Then run the complete [`supabase-schema.sql`](./supabase-schema.sql) in the Supabase SQL Editor. The schema is designed to be rerunnable and configures:

- `profiles`, `kits`, `demo_tracks`, `downloads`, `follows`, `kit_likes`, and `notifications`
- Public catalog reads and owner-only mutations
- Producer profile creation and updates
- Storage ownership paths beginning with the authenticated user ID
- `toggle_kit_like(target_kit_id)` for like state changes
- `record_kit_download(target_kit_id, target_user_id)` for download records and counters

### Storage path convention

```text
{auth-user-id}/{kit-id}/cover.webp
{auth-user-id}/{kit-id}/01-preview.mp3
{auth-user-id}/{kit-id}/kit.zip
```

Keep `archives` private. The app verifies public kit visibility, creates a short-lived signed URL, starts the browser download, and records the download through the RPC.

## Google authentication

1. In Google Cloud, create a Web OAuth client.
2. Add this Supabase callback URL to the Google client:

   ```text
   https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback
   ```

3. In Supabase, enable **Authentication → Providers → Google**.
4. Set the Supabase **Site URL** to:

   ```text
   https://drumvault-aaron.vercel.app/
   ```

5. Add these Supabase **Redirect URLs**:

   ```text
   https://drumvault-aaron.vercel.app/
   https://drumvault-aaron.vercel.app/index.html
   https://aarondanoob.github.io/drumvault-beta/
   https://aarondanoob.github.io/drumvault-beta/index.html
   http://localhost:3000/
   http://localhost:3000/index.html
   ```

The frontend uses the current browser origin for OAuth redirects, so the same frontend works on Vercel, GitHub Pages, and local development.

## Frontend configuration

The browser uses a Supabase project URL and publishable/anon key in `public/index.html`:

```js
const SUPABASE_URL = 'https://your-project.supabase.co';
const SUPABASE_ANON_KEY = 'your-publishable-key';
```

A publishable/anon key is intended for browser use. Never expose a service-role key, Google client secret, payment secret, or other privileged credential in the frontend.

## Upload limits

Authenticated producers can upload:

- PNG, JPEG, or WebP cover art up to 5 MB
- Up to three MP3/WAV demo tracks, up to 25 MB each
- ZIP archives up to 2 GB
- Title, description, kit type, price metadata, sample count, and license

Failed uploads display an error and do not report false success. The dashboard supports kit visibility changes, metadata editing, demo management, archive replacement, and deletion.

## Deployment

### Vercel

Push `main` to the connected Vercel project or deploy manually:

```bash
npx vercel login
npx vercel --prod
```

The production URL is [drumvault-aaron.vercel.app](https://drumvault-aaron.vercel.app/).

### GitHub Pages

The repository publishes the `gh-pages` branch. The deployed URL is:

```text
https://aarondanoob.github.io/drumvault-beta/
```

When publishing manually, copy `public/index.html` to the root of the `gh-pages` branch as `index.html`.

## Release checklist

- [ ] Run `supabase-schema.sql` in the production project
- [ ] Confirm `covers`, `demos`, and `archives` buckets exist
- [ ] Confirm Google OAuth is enabled
- [ ] Confirm Supabase Site URL and redirect URLs match the deployed host
- [ ] Sign in with Google on a separate device
- [ ] Create or update a producer profile
- [ ] Upload a small cover, demo, and ZIP archive
- [ ] Confirm the kit appears when public
- [ ] Preview its demo audio
- [ ] Download the ZIP from an authenticated account
- [ ] Confirm the download counter increments
- [ ] Test hiding and republishing a kit
- [ ] Delete a disposable kit and verify its Storage objects are removed

## Important limitations

- Paid-kit checkout and purchase entitlements are not implemented. A non-zero price is metadata only.
- ZIP contents are not inspected server-side for traversal, executable files, decompression bombs, or malicious payloads.
- Large uploads use direct browser-to-Storage transfer rather than resumable multipart upload.

## License

No open-source license has been declared yet. Contact the repository owner before reusing the application or its assets.
