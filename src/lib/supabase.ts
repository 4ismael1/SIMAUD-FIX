import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.error('[Supabase] Missing environment variables:');
  console.error(`  VITE_SUPABASE_URL: ${supabaseUrl ? '(set)' : '(missing)'}`);
  console.error(`  VITE_SUPABASE_ANON_KEY: ${supabaseKey ? '(set)' : '(missing)'}`);
  throw new Error(
    'Missing Supabase environment variables. Please check your .env file (see .env.example).',
  );
}

console.info('[Supabase] Client initialized.');
console.info(`[Supabase] URL: ${supabaseUrl}`);

export const supabase = createClient(supabaseUrl, supabaseKey, {
  auth: {
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: true,
    storageKey: 'simaud-auth',
  },
});

// Types for our database
export interface UserProfile {
  id: string;
  email: string;
  name: string;
  phone: string;
  cedula: string;
  role: 'admin' | 'supervisor' | 'gestor' | 'user';
  created_at: string;
  updated_at: string;
}
