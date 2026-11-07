# Kesiapan pemulihan akun

Backend untuk kode pemulihan akun username disiapkan sebagai source code. **Belum aktif** karena project Supabase produksi belum dapat diakses melalui koneksi. Jangan menampilkan tombol yang menyatakan recovery tersedia sebelum endpoint berfungsi.

Koneksi aplikasi harus dipastikan terlebih dahulu. Terapkan migrasi di `supabase/migrations/20261107141000_recovery_codes.sql` lalu deploy `supabase/functions/account-recovery/index.ts` dengan `verify_jwt=false` (fungsi memverifikasi JWT untuk penerbitan kode dan memakai kode rahasia sekali pakai untuk reset).

Lakukan tes sandbox: terbitkan kode saat login dengan password yang benar, logout, reset dengan username/kode, login dengan password baru, pastikan kode yang sudah terpakai ditolak. Pengguna yang belum menyiapkan kode saat login tidak dapat memakai metode ini; butuh pemulihan melalui bukti kepemilikan lain.

Jangan kirim email OTP ke email internal sintetis.
