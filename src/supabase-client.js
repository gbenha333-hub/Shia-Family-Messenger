// Browser client: use a publishable/anon key, never a service_role key.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
const url = window.SUPABASE_URL;
const key = window.SUPABASE_PUBLISHABLE_KEY;
export const supabase = url && key ? createClient(url, key) : null;
function requireClient(){ if(!supabase) throw new Error('Supabase غير مربوط بعد'); return supabase; }
export async function sendPhoneOtp(phone, channel='sms') {
  if(!['sms','whatsapp'].includes(channel)) throw new Error('طريقة إرسال غير مدعومة');
  const {data,error}=await requireClient().auth.signInWithOtp({phone,options:{channel}});
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

export async function registerWithPhonePassword(phone,password){
  const {data,error}=await requireClient().auth.signUp({phone,password});
  if(error)throw error;
  return data;
}
export async function loginWithPhonePassword(phone,password){
  const {data,error}=await requireClient().auth.signInWithPassword({phone,password});
  if(error)throw error;
  return data;
}

const usernameEmail = username => {
  const name=String(username).trim().toLowerCase();
  if(!/^[a-z0-9_]{3,30}$/.test(name))throw Error('اسم المستخدم يجب أن يكون 3 إلى 30 حرفاً إنكليزياً أو رقماً أو _');
  return name+'@users.shia-family.invalid';
};
export async function registerWithUsername(username,password){
  if(password.length<8)throw Error('كلمة المرور قصيرة');
  const {data,error}=await requireClient().auth.signUp({email:usernameEmail(username),password,options:{data:{username:username.toLowerCase()}}});
  if(error)throw error;
  return data;
}
export async function loginWithUsername(username,password){
  const {data,error}=await requireClient().auth.signInWithPassword({email:usernameEmail(username),password});
  if(error)throw error;
  return data;
}
