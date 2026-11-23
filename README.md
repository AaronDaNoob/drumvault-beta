# Drumvault

Responsive static marketplace prototype for drumkits and soundkits.

## Google login setup

The Google button is wired to Supabase Auth. Add your Supabase public anon key in `public/index.html` by replacing `SUPABASE_ANON_KEY` with the value from **Supabase → Project Settings → API → Publishable/anon key**. The anon key is safe for browser use; never add the service-role key.

In Supabase Auth URL Configuration, add:

```text
http://localhost:3000
http://localhost:3000/index.html
```

In production, add your Vercel URL as both the Site URL and a Redirect URL. Google OAuth must be enabled in Supabase with the Google Client ID and Client Secret.

## Run locally

```bash
npm run dev
```

The static client supports Supabase Google authentication, direct Storage uploads, creator management, public/private kits, archive downloads, and producer-uploaded demo playback. Run the latest `supabase-schema.sql` after every schema change. The current uploader does not scan ZIP contents or provide resumable uploads; do not accept untrusted large archives publicly until server-side archive validation and resumable transfer are added.

## Vercel

Import this folder into Vercel with `public` as the output directory and no build command, or run:

```bash
npx vercel --prod
```

Vercel authentication is required before deployment.
