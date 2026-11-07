'use client';
import {useEffect,useState,type FormEvent} from 'react';
import Link from 'next/link';
import {supabase} from '@/lib/supabase';
const enabled=process.env.NEXT_PUBLIC_RECOVERY_CODES_ENABLED==='true';
export default function UsernameRecovery(){
 const [setup,setSetup]=useState(false),[loggedIn,setLoggedIn]=useState(false),
 [username,setUsername]=useState(''),[code,setCode]=useState(''),
 [password,setPassword]=useState(''),[confirmation,setConfirmation]=useState(''),
 [newCode,setNewCode]=useState(''),[busy,setBusy]=useState(false),[message,setMessage]=useState(''),[error,setError]=useState('');
 useEffect(()=>{setSetup(new URLSearchParams(location.search).get('mode')==='setup');
 if(enabled){void supabase.auth.getUser().then(({data})=>setLoggedIn(Boolean(data.user))).catch(()=>setLoggedIn(false));}},[]);
 function accountEmail(username:string){const name=username.trim().toLowerCase();return name.includes('@')?name:name.normalize('NFKD').replace(/[^a-z0-9._-]+/g,'-').replace(/^[._-]+|[._-]+$/g,'')+'@akun.sikaspro.id';}
 async function submit(event:FormEvent<HTMLFormElement>){
  event.preventDefault();setBusy(true);setError('');setMessage('');
  try{
   if(!enabled)throw Error('Pemulihan belum diaktifkan.');
   if(setup&&!loggedIn)throw Error('Masuk ke aplikasi terlebih dahulu.');
   if(!setup&&(password!==confirmation||password.length<8||password.length>128))throw Error('Password harus 8–128 karakter dan kedua isian sama.');
   const body=setup?{action:'issue',currentPassword:password}:{action:'redeem',email:accountEmail(username),code:code.trim(),newPassword:password};
   const {data,error:failure}=await supabase.functions.invoke('account-recovery',{body});
   if(failure){let reason='Permintaan tidak dapat diproses.';try{const detail=await failure.context?.json();reason=detail?.error||reason;}catch{}throw Error(reason);}
   if(!data?.ok)throw Error(data?.error||'Pemulihan gagal.');
   if(setup){setNewCode(data.code);setMessage('Simpan kode sekarang. Kode sebelumnya otomatis tidak berlaku.');}
   else{await supabase.auth.signOut();setCode('');setMessage('Password berhasil diganti. Silakan login dengan password baru.');}
   setPassword('');setConfirmation('');
  }catch(err){setError((err as Error).message);}finally{setBusy(false)}
 }
 const inputStyle={display:'block' as const,width:'100%',boxSizing:'border-box' as const,padding:12,border:'1px solid #94a3b8',borderRadius:9,marginTop:6,marginBottom:12,fontSize:16};
 return <main style={{minHeight:'80vh',padding:20,display:'grid',placeItems:'center'}}>
  <section style={{maxWidth:460,width:'100%',border:'1px solid #94a3b855',borderRadius:16,padding:24,background:'var(--card, #ffffff)',color:'var(--text, #1e293b)'}}>
   <small>BANTU BERES · KEAMANAN AKUN</small><h1>{setup?'Buat kode pemulihan':'Lupa password?'}</h1>
   <p>{setup?'Buat kode sekali pakai saat masih login. Konfirmasi password kamu.':'Gunakan username dan kode rahasia yang sudah disimpan sebelumnya.'}</p>
   {!enabled?<p role="status">Layanan kode pemulihan belum tersedia untuk aplikasi ini. Login biasa tetap dapat digunakan.</p>:
    setup&&!loggedIn?<p>Login lebih dahulu untuk membuat kode pemulihan.</p>:
    newCode?<><p role="status">{message}</p><label>Kode pemulihan<textarea readOnly style={{...inputStyle,minHeight:80}} value={newCode}/></label>
      <button type="button" onClick={()=>void navigator.clipboard.writeText(newCode)}>Salin kode</button></>:
    message?<p role="status">{message}</p>:
    <form onSubmit={submit}>
     {!setup&&<><label>Username<input required autoComplete="username" maxLength={128} style={inputStyle} value={username} onChange={e=>setUsername(e.target.value)}/></label>
       <label>Kode pemulihan<input required autoComplete="off" style={inputStyle} value={code} onChange={e=>setCode(e.target.value)} maxLength={60}/></label></>}
     <label>{setup?'Password saat ini':'Password baru'}<input type="password" required style={inputStyle} autoComplete={setup?'current-password':'new-password'} minLength={setup?undefined:8} maxLength={128} value={password} onChange={e=>setPassword(e.target.value)}/></label>
     {!setup&&<label>Konfirmasi password<input type="password" required style={inputStyle} minLength={8} maxLength={128} autoComplete="new-password" value={confirmation} onChange={e=>setConfirmation(e.target.value)}/></label>}
     {error&&<p role="alert" style={{color:'#b91c1c'}}>{error}</p>}
     <button type="submit" disabled={busy} style={{background:'#315bad',color:'#fff',border:0,borderRadius:9,padding:12}}>{busy?'Memproses…':setup?'Buat kode pemulihan':'Ganti password'}</button>
    </form>}
   <p><Link href="/">Kembali ke aplikasi</Link></p>
  </section>
 </main>;
}
