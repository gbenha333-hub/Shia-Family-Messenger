/* Mawadda isolated email/password auth override */
(() => {
  const $ = id => document.getElementById(id);
  const gate=$('authGate'), login=$('authLogin'), signup=$('authSignup'), otp=$('authOtp');
  if(!gate||!login||!signup||!window.supabase||!window.SUPABASE_URL||!window.SUPABASE_PUBLISHABLE_KEY)return;
  const sb=window.supabase.createClient(window.SUPABASE_URL,window.SUPABASE_PUBLISHABLE_KEY);
  const validEmail=v=>/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test((v||'').trim());
  const notify=s=>typeof window.toast==='function'?window.toast(s):alert(s);
  const ensurePassword=(panel,id,autocomplete)=>{
    let el=$(id); if(el)return el;
    el=document.createElement('input');el.id=id;el.className='auth-input';el.type='password';
    el.autocomplete=autocomplete;el.placeholder='كلمة المرور (6 أحرف على الأقل)';el.setAttribute('aria-label','كلمة المرور');
    const btn=panel.querySelector('.auth-primary');panel.insertBefore(el,btn);return el;
  };
  const loginPass=ensurePassword(login,'loginPassword','current-password');
  const signupPass=ensurePassword(signup,'signupPassword','new-password');
  if(otp)otp.hidden=true;
  const show=p=>{login.hidden=p!=='login';signup.hidden=p!=='signup';if(otp)otp.hidden=true};
  $('showSignup')?.addEventListener('click',e=>{e.stopImmediatePropagation();show('signup')},true);
  $('showLogin')?.addEventListener('click',e=>{e.stopImmediatePropagation();show('login')},true);
  $('loginContinue')?.addEventListener('click',async e=>{
    e.preventDefault();e.stopImmediatePropagation();
    const email=$('loginEmail').value.trim(),password=loginPass.value;
    if(!validEmail(email))return notify('أدخل بريداً إلكترونياً صحيحاً');
    if(password.length<6)return notify('أدخل كلمة المرور');
    const {data,error}=await sb.auth.signInWithPassword({email,password});
    if(error||!data.user)return notify('البريد الإلكتروني أو كلمة المرور غير صحيحة');
    gate.hidden=true;notify('أهلاً بك في مَوَدَّة');
  },true);
  $('signupContinue')?.addEventListener('click',async e=>{
    e.preventDefault();e.stopImmediatePropagation();
    const name=$('signupName').value.trim(),email=$('signupEmail').value.trim(),password=signupPass.value;
    const birth=$('signupBirth').value,gender=$('signupGender').value;
    if(name.length<2)return notify('اكتب الاسم');
    if(!validEmail(email))return notify('أدخل بريداً إلكترونياً صحيحاً');
    if(password.length<6)return notify('كلمة المرور يجب أن تكون 6 أحرف على الأقل');
    if(!birth||!gender)return notify('أكمل تاريخ الميلاد والجنس');
    const {data,error}=await sb.auth.signUp({email,password,options:{data:{name,birth,gender}}});
    if(error)return notify('تعذر إنشاء الحساب: '+error.message);
    if(data.session){gate.hidden=true;notify('تم إنشاء الحساب والدخول إلى مَوَدَّة');}
    else notify('تم إنشاء الحساب. إعداد Supabase ما زال يطلب تأكيد البريد؛ سنعطله من إعدادات المشروع.');
  },true);
})();