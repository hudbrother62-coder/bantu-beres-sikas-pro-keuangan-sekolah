import {createClient} from 'npm:@supabase/supabase-js@2.116.0'

const allowedOrigin='https://bantu-beres-sikas-pro-keuangan-seko.vercel.app'
const cors={'Access-Control-Allow-Origin':allowedOrigin,'Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type','Content-Type':'application/json'}
const reply=(body:Record<string,unknown>,status=200)=>new Response(JSON.stringify(body),{status,headers:cors})
const fingerprint=async(value:string)=>Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(value)))).map(b=>b.toString(16).padStart(2,'0')).join('')
const loginEmail=(value:string)=>{
  const input=value.trim().toLowerCase()
  if(/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(input)) return input
  const slug=input.normalize('NFKD').replace(/[^a-z0-9._-]+/g,'-').replace(/^[._-]+|[._-]+$/g,'')
  return slug?`${slug}@akun.sikaspro.id`:''
}

Deno.serve(async req=>{
  if(req.headers.get('origin')!==allowedOrigin) return reply({ok:false,error:'Sumber permintaan tidak diizinkan.'},403)
  if(req.method==='OPTIONS') return new Response('ok',{headers:cors})
  if(req.method!=='POST') return reply({ok:false,error:'Metode permintaan tidak didukung.'})
  try{
    const {identifier='',password='',fullName=''}=await req.json()
    const username=String(identifier).trim(),email=loginEmail(username),name=String(fullName).trim()
    if(username.length<3||username.length>60||!email) return reply({ok:false,error:'Username harus terdiri dari 3–60 karakter.'})
    if(String(password).length<8) return reply({ok:false,error:'Password minimal 8 karakter.'})
    if(name.length<2) return reply({ok:false,error:'Nama lengkap wajib diisi.'})
    const secret=JSON.parse(Deno.env.get('SUPABASE_SECRET_KEYS')||'{}').default||Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
    if(!secret) return reply({ok:false,error:'Layanan pendaftaran belum terkonfigurasi. Hubungi pengelola aplikasi.'})
    const admin=createClient(Deno.env.get('SUPABASE_URL')!,secret,{auth:{autoRefreshToken:false,persistSession:false}})
    const ip=(req.headers.get('x-forwarded-for')||req.headers.get('cf-connecting-ip')||'').split(',')[0].trim()
    if(!ip) return reply({ok:false,error:'Identitas jaringan tidak tersedia. Muat ulang halaman lalu coba lagi.'})
    const {data:allowed,error:limitError}=await admin.rpc('consume_registration_attempt',{client_fingerprint:await fingerprint(ip)})
    if(limitError) return reply({ok:false,error:'Pendaftaran sementara tidak tersedia. Silakan coba lagi.'})
    if(!allowed) return reply({ok:false,error:'Terlalu banyak percobaan pendaftaran. Tunggu 30 menit lalu coba kembali.'})
    const {data,error}=await admin.auth.admin.createUser({email,password:String(password),email_confirm:true,user_metadata:{username,full_name:name}})
    if(error){
      const duplicate=/already|registered|exists/i.test(error.message)
      return reply({ok:false,error:duplicate?'Username sudah terdaftar. Pilih menu Masuk atau gunakan username lain.':`Pendaftaran gagal: ${error.message}`})
    }
    return reply({ok:true,email,userId:data.user.id})
  }catch(error){return reply({ok:false,error:`Pendaftaran gagal diproses: ${error instanceof Error?error.message:'permintaan tidak valid'}`})}
})
