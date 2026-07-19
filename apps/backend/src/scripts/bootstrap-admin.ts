/**
 * Development Admin Bootstrap Script
 *
 * This script creates an admin user for development purposes.
 * It reads credentials from environment variables.
 *
 * Environment Variables Required:
 * - ADMIN_EMAIL: Email for the admin user
 * - ADMIN_PASSWORD: Password for the admin user  
 * - ADMIN_NAME: Display name for the admin user
 * - SUPABASE_URL: Supabase project URL
 * - SUPABASE_SERVICE_KEY: Supabase service role key
 *
 * Usage:
 * npx ts-node src/scripts/bootstrap-admin.ts
 *
 * Or with environment file:
 * ADMIN_EMAIL=admin@example.com ADMIN_PASSWORD=password ADMIN_NAME=Admin npx ts-node src/scripts/bootstrap-admin.ts
 */

import { createClient, SupabaseClient } from '@supabase/supabase-js';
import * as dotenv from 'dotenv';

dotenv.config({ path: '.env.local' });
dotenv.config({ path: '.env' });

interface Config {
  supabaseUrl: string;
  supabaseServiceKey: string;
  adminEmail: string;
  adminPassword: string;
  adminName: string;
}

function getConfig(): Config {
  const supabaseUrl = process.env.SUPABASE_URL;
  const supabaseServiceKey = process.env.SUPABASE_SERVICE_KEY || process.env.SUPABASE_ANON_KEY;
  const adminEmail = process.env.ADMIN_EMAIL;
  const adminPassword = process.env.ADMIN_PASSWORD;
  const adminName = process.env.ADMIN_NAME;

  if (!supabaseUrl || !supabaseServiceKey) {
    throw new Error('Missing required environment variables: SUPABASE_URL, SUPABASE_SERVICE_KEY');
  }

  if (!adminEmail || !adminPassword || !adminName) {
    throw new Error(
      'Missing required environment variables: ADMIN_EMAIL, ADMIN_PASSWORD, ADMIN_NAME',
    );
  }

  return {
    supabaseUrl,
    supabaseServiceKey,
    adminEmail,
    adminPassword,
    adminName,
  };
}

async function checkAdminExists(supabase: SupabaseClient, email: string): Promise<string | null> {
  const { data, error } = await supabase.auth.admin.listUsers();

  if (error) {
    throw new Error(`Failed to list users: ${error.message}`);
  }

  const admin = data.users.find((user) => user.email === email);
  return admin?.id || null;
}

async function createAdminUser(
  supabase: SupabaseClient,
  email: string,
  password: string,
  name: string,
): Promise<string> {
  const { data, error } = await supabase.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { name },
  });

  if (error) {
    throw new Error(`Failed to create user: ${error.message}`);
  }

  const user = data?.user;
  if (!user) {
    throw new Error('User was not returned from creation');
  }

  console.log(`Created user: ${user.id}`);
  return user.id;
}

async function promoteToAdmin(supabase: SupabaseClient, userId: string): Promise<void> {
  const { error } = await supabase.from('profiles').update({ role: 'admin' }).eq('id', userId);

  if (error) {
    throw new Error(`Failed to update profile role: ${error.message}`);
  }

  console.log(`Promoted user ${userId} to admin`);
}

async function bootstrapAdmin(): Promise<void> {
  console.log('🚀 Starting admin bootstrap...\n');

  const config = getConfig();
  console.log(`📧 Admin email: ${config.adminEmail}`);
  console.log(`👤 Admin name: ${config.adminName}\n`);

  // Create Supabase client with service role key
  const supabase = createClient(config.supabaseUrl, config.supabaseServiceKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });

  try {
    // Check if admin already exists
    const existingAdminId = await checkAdminExists(supabase, config.adminEmail);

    if (existingAdminId) {
      console.log('✅ Admin user already exists');
      console.log(`   User ID: ${existingAdminId}`);

      // Check if already an admin
      const { data: profile } = await supabase
        .from('profiles')
        .select('role')
        .eq('id', existingAdminId)
        .single();

      if (profile?.role === 'admin') {
        console.log('   Role: admin (no changes needed)');
      } else {
        console.log('   Role: user (promoting to admin...)');
        await promoteToAdmin(supabase, existingAdminId);
      }

      console.log('\n✨ Bootstrap complete! No changes made.');
      return;
    }

    // Create new admin user
    console.log('📝 Creating new admin user...');
    const userId = await createAdminUser(
      supabase,
      config.adminEmail,
      config.adminPassword,
      config.adminName,
    );

    // Wait for profile trigger to fire
    console.log('⏳ Waiting for profile creation...');
    await new Promise((resolve) => setTimeout(resolve, 1000));

    // Promote to admin
    console.log('⬆️  Promoting to admin...');
    await promoteToAdmin(supabase, userId);

    console.log('\n✨ Bootstrap complete! Admin user created successfully.');
    console.log('\n📋 Credentials:');
    console.log(`   Email: ${config.adminEmail}`);
    console.log(`   Password: ${config.adminPassword}`);
  } catch (error) {
    console.error('\n❌ Bootstrap failed:', error instanceof Error ? error.message : error);
    process.exit(1);
  }
}

// Run if called directly
bootstrapAdmin().catch((error) => {
  console.error('Unhandled error:', error);
  process.exit(1);
});

export { bootstrapAdmin, getConfig };
