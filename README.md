# Shia Family Messenger — شبكة الأسرة الشيعية

Independent messaging project. `index.html` is the existing local interactive prototype (9 themes, demo chats, audio recording, media selection). **It is not connected to a live server.**

## Ready for future Supabase deployment

- `supabase/migrations/20261013_001_messaging.sql`: profiles, conversations, members, messages, RLS policies and private media storage.
- `src/supabase-client.js`: browser API adapter for phone OTP, sending and realtime messages, and uploading media.
- `config.example.js`: placeholder for public Supabase project configuration. Do not commit secrets.

## Next steps

1. Create a new private GitHub repository named `shia-family-messenger`, then push this folder.
2. Once the separate Supabase project is available, apply the SQL migration using the SQL editor or Supabase CLI after review.
3. In Supabase Auth, enable **Phone** and configure an SMS provider; disable email login as needed. SMS provider fees are separate.
4. Enable realtime publication for `public.messages`, and configure storage limits/policies as needed.
5. Connect the UI to the API adapter, add verified account onboarding, message pagination and robust moderation/rate limits before production.
6. Use HTTPS to permit microphone capture.

**Security note:** This is an initial foundation, not a production-complete secure messenger. No end-to-end encryption, push notifications, real calls, delivery receipts, abuse controls or deployment yet. Supabase realtime subscriptions and the SQL policies must be tested with at least two authenticated accounts before launch.

Existing GitHub/Supabase projects were not modified.
