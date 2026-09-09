import fs from 'node:fs'

const path = 'src/components/sikas-app.tsx'
let source = fs.readFileSync(path, 'utf8')
const start = source.indexOf('function Team(')
const end = source.indexOf('\nfunction SchoolSettings(', start)
if (start < 0 || end < 0) throw new Error('Team block not found')

const replacement = String.raw`function Team({school,notify}:{school:School;notify:(s:string,k?:'ok'|'error')=>void}){
 const [members,setMembers]=useState<{user_id:string;role:string;status:string;created_at:string;profiles?:{full_name:string;username:string;last_seen_at:string|null}}[]>([]),[invites,setInvites]=useState<{id:string;expires_at:string;accepted_at:string|null;revoked_at:string|null}[]>([]),[inviteUrl,setInviteUrl]=useState(''),[busy,setBusy]=useState(false)
 const load=()=>Promise.all([supabase.from('school_members').select('user_id,role,status,created_at,profiles(full_name,username,last_seen_at)').eq('school_id',school.id).order('created_at'),supabase.from('invitations').select('id,expires_at,accepted_at,revoked_at').eq('school_id',school.id).order('created_at',{ascending:false})]).then(([a,b])=>{if(a.error||b.error)return notify(\`Tim sekolah gagal dimuat: \${(a.error||b.error)?.message}\`,'error');setMembers((a.data||[]) as unknown as typeof members);setInvites((b.data||[]) as typeof invites)})
 useEffect(()=>{load()},[school.id])
 const copy=async(url:string)=>{try{await navigator.clipboard.writeText(url);notify('Link undangan berhasil di-copy.')}catch{prompt('Salin link undangan ini:',url);notify('Link siap disalin dari kotak yang muncul.')}}
 const invite=async()=>{setBusy(true);const {data,error}=await supabase.rpc('create_invitation',{target_school:school.id});setBusy(false);if(error)return notify(\`Link undangan gagal dibuat: \${error.message}\`,'error');const url=\`\${location.origin}/?invite=\${data}\`;setInviteUrl(url);await copy(url);load()}
 const remove=async(uid:string,name:string)=>{if(!confirm(\`Hapus akses \${name}? Akun ini akan langsung kehilangan akses ke sekolah, tetapi akun login dan riwayat transaksi tetap aman.\`))return;const {error}=await supabase.rpc('remove_school_member',{target_school:school.id,target_user:uid});if(error)return notify(\`Akses belum dihapus: \${error.message}\`,'error');notify(\`Akses \${name} berhasil dihapus\`);load()}
 const activeStaff=members.filter(m=>m.role==='staff'&&m.status==='active').length
 return <div className="team-page">
  <div className="team-hero"><div><span className="eyebrow">AKSES TIM SEKOLAH</span><h2>Hubungkan staf sekolah</h2><p>Bagikan satu workspace sekolah tanpa membagikan password Kepala Sekolah. Setiap staf tetap memakai akun sendiri.</p></div><div className="team-hero-stat"><b>{activeStaff}</b><span>staf aktif</span></div></div>
  <div className="team-actions"><button className="primary small" onClick={invite} disabled={busy}><Plus/>{busy?'Membuat link…':'Buat link undangan'}</button>{inviteUrl&&<div className="invite-box"><div><small>LINK UNDANGAN TERBARU</small><code>{inviteUrl}</code><span>Berlaku 7 hari · khusus akun staf sekolah</span></div><button className="secondary" onClick={()=>copy(inviteUrl)}>⧉ Salin link</button></div>}</div>
  <div className="team-grid"><Card title="Orang yang punya akses"><div className="team-members">{members.length?members.map(m=>{const name=m.profiles?.full_name||'Pengguna';return <div className="team-member" key={m.user_id}><div className="team-avatar">{name.slice(0,1).toUpperCase()}</div><div className="team-member-main"><b>{name}</b><span>@{m.profiles?.username||'—'} · bergabung {new Date(m.created_at).toLocaleDateString('id-ID')}</span><small>{m.profiles?.last_seen_at?\`Terakhir aktif \${new Date(m.profiles.last_seen_at).toLocaleString('id-ID')}\`:'Belum tercatat login'}</small></div><div className="team-member-side"><Badge tone={m.role==='principal'?'blue':m.status==='active'?'green':'muted'}>{m.role==='principal'?'Kepala Sekolah':m.status==='active'?'Staf aktif':'Akses dicabut'}</Badge>{m.role==='staff'&&m.status==='active'&&<button className="link danger" onClick={()=>remove(m.user_id,name)}>Hapus akses</button>}</div></div>}) : <Empty text="Belum ada anggota tim."/>}</div></Card><Card title="Undangan"><div className="quick-list">{invites.length?invites.map(i=><p key={i.id}><span><b>{i.accepted_at?'Undangan sudah digunakan':'Undangan staf sekolah'}</b><small>Berlaku sampai {new Date(i.expires_at).toLocaleDateString('id-ID')}</small></span><Badge tone={i.accepted_at?'green':i.revoked_at?'muted':'orange'}>{i.accepted_at?'Diterima':i.revoked_at?'Dibatalkan':'Aktif'}</Badge></p>):<Empty text="Belum ada link undangan."/>}</div></Card></div>
  <div className="team-note"><b>Hak akses staf</b><span>Staf memakai akun sendiri dan bekerja pada data sekolah yang sama. Kepala Sekolah tetap satu-satunya pengelola akses tim.</span></div>
 </div>
}`

source = source.slice(0, start) + replacement + source.slice(end)
fs.writeFileSync(path, source)
