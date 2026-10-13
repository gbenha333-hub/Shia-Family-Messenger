// Browser client: use a publishable/anon key, never a service_role key.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
const url = window.SUPABASE_URL;
const key = window.SUPABASE_PUBLISHABLE_KEY;
export const supabase = url && key ? createClient(url, key) : null;
function requireClient(){ if(!supabase) throw new Error('Supabase غير مربوط بعد'); return supabase; }
export async function sendPhoneOtp(phone) {
  const {data,error}=await requireClient().auth.signInWithOtp({phone});
  if(error) throw error;
  return data;
}
export async function verifyPhoneOtp(phone, token) {
  const {data,error}=await requireClient().auth.verifyOtp({phone,token,type:'sms'});
  if(error) throw error;
  return data;
}
export async function sendMessage(conversationId, body) {
  const client=requireClient();
  const {data:{user},error:authError}=await client.auth.getUser();
  if(authError||!user) throw new Error('يرجى تسجيل الدخول');
  const {data,error}=await client.from('messages').insert({conversation_id:conversationId,sender_id:user.id,body}).select().single();
  if(error) throw error;
  return data;
}
export function subscribeToMessages(conversationId, onMessage) {
  return requireClient().channel('chat:'+conversationId).on('postgres_changes',{
    event:'INSERT',schema:'public',table:'messages',filter:'conversation_id=eq.'+conversationId
  },payload=>onMessage(payload.new)).subscribe();
}
export async function uploadMedia(conversationId,file) {
  const client=requireClient();
  const {data:{user},error:authError}=await client.auth.getUser();
  if(authError||!user) throw new Error('يرجى تسجيل الدخول');
  const ext=(file.name.split('.').pop()||'bin').replace(/[^a-z0-9]/gi,'').slice(0,8);
  const path=`${conversationId}/${user.id}/${crypto.randomUUID()}.${ext}`;
  const {error}=await client.storage.from('chat-media').upload(path,file,{contentType:file.type,upsert:false});
  if(error) throw error;
  return path;
}
