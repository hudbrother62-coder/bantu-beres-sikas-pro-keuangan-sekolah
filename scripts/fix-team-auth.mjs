import fs from 'node:fs'

const path='src/components/sikas-app.tsx'
let source=fs.readFileSync(path,'utf8')

// Repair staff invitation onboarding after the Team UI enhancer runs.
const authStart=source.indexOf('function Auth(')
const authEnd=source.indexOf('\nfunction Onboarding(',authStart)
if(authStart<0||authEnd<0) throw new Error('Auth block not found')

const auth=String.raw`function Auth({onDone,notify,inviteToken}:{onDone:(id:string)=>void;notify:(s:string,k?:'ok'|'error')=>void;inviteToken?:string|null}){
 const [mode,setMode]=useState<'login'|'signup'>(inviteToken?'signup':'login'),[busy,setBusy]=useState(false),[problem,setProblem]=useState('')
 const changeMode=(next:'login'|'signup')=>{setMode(next);setProblem('')}
 const fail=(message:string)=>{const text=authProblem(message);setProblem(text);notify(text,'error')}
 const submit=async(e:React.FormEvent<HTMLFormElement>)=>{e.preventDefault();setBusy(true);setProblem('');const fd=new FormData(e.currentTarget),identifier=String(fd.get('identifier')).trim(),password=String(fd.get('password')),email=loginEmail(identifier);try{if(!email)return fail('Username tidak valid. Gunakan minimal 3 huruf atau angka.');if(mode==='signup'){const {data,error}=await supabase.functions.invoke('register-username',{body:{identifier,password,fullName:String(fd.get('full_name'))}});if(error)return fail(error.message);if(!data?.ok)return fail(data?.error||'Akun tidak berhasil dibuat.')}const result=await supabase.auth.signInWithPassword({email,password});if(result.error)return fail(result.error.message);if(inviteToken){const joined=await supabase.rpc('accept_invitation',{raw_token:inviteToken});if(joined.error)return fail('Undangan tidak dapat diterima: '+joined.error.message);history.replaceState({},'',location.pathname);notify('Akun staf berhasil dibuat dan bergabung ke sekolah');onDone(result.data.user.id)}else{notify(mode==='login'?'Berhasil masuk':'Akun kepala sekolah berhasil dibuat dan langsung masuk');onDone(result.data.user.id)}}catch(error){fail(error instanceof Error?error.message:'Terjadi masalah saat memproses akun.')}finally{setBusy(false)}}
 return <div className="auth-page"><section className="auth-hero"><Brand/><h1>Keuangan sekolah<br/><em>lebih tertib.</em></h1><p>Transaksi, tagihan, tunggakan, anggaran, kwitansi dan laporan dalam satu tempat yang aman.</p><div className="hero-points"><span>✓ Satu pintu transaksi</span><span>✓ Laporan otomatis</span><span>✓ Nyaman di HP</span></div></section><section className="auth-card">{inviteToken&&<div className="team-note"><b>Undangan staf sekolah</b><span>Buat akun Anda sendiri untuk bergabung ke workspace sekolah. Akun ini akan menjadi Staf Sekolah, bukan Kepala Sekolah.</span></div>}<div className="tabs">{!inviteToken&&<button type="button" className={mode==='login'?'active':''} onClick={()=>changeMode('login')}>Masuk</button>}{!inviteToken&&<button type="button" className={mode==='signup'?'active':''} onClick={()=>changeMode('signup')}>Daftar</button>}</div><h2>{inviteToken?'Buat akun staf sekolah':mode==='login'?'Selamat datang':'Buat akun kepala sekolah'}</h2><p>{inviteToken?'Gunakan username dan password baru Anda. Setelah akun dibuat, undangan akan langsung menghubungkan Anda sebagai Staf Sekolah.':mode==='login'?'Masuk menggunakan username dan password.':'Akun langsung aktif dan otomatis menjadi Kepala Sekolah.'}</p><form onSubmit={submit}>{mode==='signup'&&<Field label="Nama lengkap" name="full_name" autoComplete="name" required/>}<Field label="Username" name="identifier" type="text" autoComplete="username" placeholder="Contoh: staf01" minLength={3} required/><Field label="Password" name="password" type="password" autoComplete={mode==='login'?'current-password':'new-password'} minLength={8} required/>{problem&&<div className="form-error" role="alert"><b>{inviteToken?'Pendaftaran staf gagal':mode==='login'?'Tidak bisa masuk':'Tidak bisa membuat akun'}</b><span>{problem}</span></div>}<button className="primary" disabled={busy}>{busy?'Memproses…':inviteToken?'Buat akun staf':mode==='login'?'Masuk':'Buat akun'}</button></form><small className="hint">{inviteToken?'Akun staf memakai username dan password sendiri. Jangan gunakan akun Kepala Sekolah untuk link ini.':'Username tidak harus berupa email asli. Simpan username dan password untuk login berikutnya.'}</small></section></div>
}
`
source=source.slice(0,authStart)+auth+source.slice(authEnd)

// Make the staff removal action explicit in the Team list.
source=source.replace('>Hapus akses</button>','>Nonaktifkan staf</button>')
fs.writeFileSync(path,source)
