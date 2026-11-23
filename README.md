# DrumVault

DrumVault is a lightweight producer marketplace for discovering, previewing, publishing, and downloading sample kits. The current implementation preserves the existing single-page visual experience while connecting authentication, PostgreSQL metadata, and Supabase Storage.

## Production site

- Website: https://drumvault-aaron.vercel.app/
- Repository: https://github.com/AaronDaNoob/drumvault-beta

## Current capabilities

- Google authentication through Supabase Auth
- Persistent browser sessions
- Public marketplace catalog backed by `public.kits`
- Search and genre/price filtering
- Public kit detail pages with direct-share hash URLs
- Producer-uploaded cover art and audio demos
- Private archive storage with authenticated downloads
- Signed/authorized archive access through Supabase Storage policies
- Download records and producer download counters
- Public/private kit visibility
- Creator dashboard with kit visibility, editing, and deletion controls
- Producer profile settings for username, display name, biography, and social links
- Public producer profile pages
- Dark mode and responsive mobile layout
- License selection for new kits: royalty-free, all rights reserved, CC0, or custom

## Project structure

```text
public/index.html       Frontend application
supabase-schema.sql     Idempotent database, RLS, RPC, and Storage policies
vercel.json             Existing Vercel routing configuration
package.json            Local static-server scripts
.gitignore              Local and deployment exclusions
```

## Run locally

```bash
npm run dev
```

The local server serves `public/`. The production-origin constant is intentionally used for shared links and OAuth redirects so copied links do not point at localhost.

## Supabase setup

Create three Storage buckets with these exact names:

| Bucket | Visibility | Purpose |
|---|---|---|
| `covers` | Public | Producer cover artwork |
| `demos` | Private or public with matching policies | Uploaded audio previews |
| `archives` | Private | ZIP kit files |

Then run the complete `supabase-schema.sql` in the Supabase SQL Editor. The script uses `drop policy if exists`, `create or replace function`, and `alter table ... add column if not exists` so it can be safely re-run as the schema evolves.

The schema configures:

- `profiles`, `kits`, `demo_tracks`, and `downloads`
- Producer ownership rules
- Public/private kit visibility
- Owner-only profile and kit mutations
- Storage path rules requiring the authenticated user ID as the first path segment
- Public cover/demo access for public kits
- Protected archive access
- `record_kit_download(uuid)`, which derives the downloader from `auth.uid()` and updates counters server-side

Use paths in this shape:

```text
{auth-user-id}/{kit-id}/cover.webp
{auth-user-id}/{kit-id}/01-preview.mp3
{auth-user-id}/{kit-id}/kit.zip
```

## Google login configuration

1. In Google Cloud, create a Web OAuth client.
2. Use this Supabase callback URL:

```text
https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback
```

3. In Supabase, enable **Authentication → Providers → Google** and paste the Google Client ID and Client Secret.
4. In **Authentication → URL Configuration**, set the production Site URL to:

```text
https://drumvault-aaron.vercel.app
```

5. Add these redirect URLs:

```text
https://drumvault-aaron.vercel.app
https://drumvault-aaron.vercel.app/index.html
http://localhost:3000
http://localhost:3000/index.html
```

## Frontend configuration

The browser uses the Supabase project URL and publishable key in `public/index.html`:

```js
const SUPABASE_URL = 'https://your-project.supabase.co';
const SUPABASE_ANON_KEY = 'your-publishable-key';
```

A publishable/anon key is intended for browser use. Never add a Supabase service-role key, Google client secret, payment secret, or other privileged credential to this file.

## Upload behavior

Authenticated producers can upload:

- PNG, JPEG, or WebP cover art up to 5 MB
- Up to three MP3/WAV demos, up to 25 MB each
- ZIP archives up to 2 GB
- Title, description, genre, price, and license metadata

The client stores exact Storage object paths in the database. Failed operations display an error instead of reporting a false success. The creator dashboard can change visibility, edit metadata, and remove the associated database/storage records.

## Download behavior

Downloads require an authenticated user and a public kit. The app:

1. Loads the kit row and exact `archive_path`.
2. Verifies public visibility through the database query and RLS.
3. Downloads the actual object from the private `archives` bucket.
4. Creates a local browser download with a sanitized `.zip` filename.
5. Records the download through `record_kit_download(uuid)` only after the file is retrieved.

If the database points to an object that is missing from Storage, the UI reports that archive as missing rather than returning a fake download.

## Vercel deployment

The existing project is already linked to Vercel. Deploy from this directory with:

```bash
npx vercel login
npx vercel --prod
```

The project is static, so no build command is required. The production alias is:

```text
https://drumvault-aaron.vercel.app
```

After deployment, verify that Vercel Deployment Protection is disabled if the site should be publicly accessible.

## Release checklist

- [ ] Run `supabase-schema.sql` in the production Supabase project.
- [ ] Confirm `covers`, `demos`, and `archives` buckets exist.
- [ ] Confirm Google OAuth is enabled and callback URLs match.
- [ ] Confirm Supabase Site URL is the Vercel domain.
- [ ] Sign in with Google on the production site.
- [ ] Create/update a producer profile.
- [ ] Upload a small valid ZIP and demo file.
- [ ] Confirm the kit appears in discovery when public.
- [ ] Download the ZIP from a second authenticated account.
- [ ] Open the downloaded archive and verify its contents.
- [ ] Test making the kit private, then public again.
- [ ] Test deleting a disposable kit and confirm its Storage objects are removed.

## Known production limitations

The current client validates file extensions, MIME types, and size limits, but does not inspect ZIP contents for path traversal, executable files, decompression bombs, or malicious payloads. It also uploads large files directly without resumable multipart transfer. Before accepting untrusted multi-gigabyte archives at scale, add a server-side archive validation worker and resumable upload flow.

Paid-kit checkout and purchase entitlements are not implemented. A non-zero price is currently metadata only; do not advertise paid downloads until payment processing and server-side entitlement checks are added.
