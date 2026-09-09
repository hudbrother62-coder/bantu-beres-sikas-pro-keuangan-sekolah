import {createBrowserClient} from '@supabase/ssr'
const url=process.env.NEXT_PUBLIC_SUPABASE_URL||'https://gjzcbqyzyvkgexvzofbq.supabase.co'
const key=process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY||'sb_publishable_ZeUDdrYZMiTRwX_WD_q3eg_3w7hNIo9'
export const supabase=createBrowserClient(url,key)
export type School={id:string;name:string;npsn:string|null;academic_year:string}
export type Member={school_id:string;role:'principal'|'staff';status:string;schools:School}
export type Student={id:string;nis:string;nisn:string|null;name:string;guardian_name:string|null;guardian_phone:string|null;status:string;class_id:string|null;classes?:{name:string}|null}
export type Cash={id:string;name:string;type:string;opening_balance:number}
export type Tx={id:string;number:string;tx_date:string;kind:'income'|'expense'|'transfer';category:string;description:string;amount:number;status:string;cash_account_id:string|null}
export type Bill={id:string;student_id:string;title:string;period:string|null;due_date:string|null;amount:number;paid_amount:number;status:string;students?:{name:string;nis:string}|null}
