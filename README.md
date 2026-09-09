# Bantu Beres SIKAS Pro

Sistem Keuangan Sekolah Terintegrasi.

## Local setup

1. Copy `.env.example` to `.env.local` and fill the Supabase URL and publishable key.
2. Apply migrations in `supabase/migrations` in order.
3. Run `npm install` and `npm run dev`.

## Production

Set `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` in Vercel. Never expose a Supabase secret or service-role key to the browser.
