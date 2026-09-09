import type { Metadata } from 'next'
import { Geist } from 'next/font/google'
import './globals.css'
import './team-ui.css'
const geist=Geist({subsets:['latin']})
export const metadata:Metadata={title:'Bantu Beres SIKAS Pro',description:'Sistem Keuangan Sekolah Terintegrasi',manifest:'/manifest.webmanifest'}
export default function RootLayout({children}:{children:React.ReactNode}){return <html lang="id"><body className={geist.className}>{children}</body></html>}
