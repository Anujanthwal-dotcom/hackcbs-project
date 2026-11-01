#!/usr/bin/env node
/**
 * KisaanBandhu – Mobile Run Script
 *
 * Full one-command startup sequence:
 *   1. Load and embed all active backend credentials (.env)
 *   2. Start MongoDB via Docker Compose
 *   3. Start NestJS backend with Gemini, Meko, and Telephony environment
 *   4. Wait for backend to be reachable on :3000
 *   5. Set up ADB reverse tunnel (tcp:3000 ↔ tcp:3000)
 *   6. Launch Flutter with all --dart-define keys (Gemini, Mapbox, Google Places, Backend URL)
 *
 * Usage: npm run mobile:run
 */

import { spawn, spawnSync } from 'child_process';
import path from 'path';
import os from 'os';
import fs from 'fs';
import http from 'http';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, '..');
const backendDir = path.join(rootDir, 'backend');
const mobileDir = path.join(rootDir, 'mobile');
const envFile = path.join(backendDir, '.env');

// ── Parse backend/.env file ──────────────────────────────────────────────────
function loadEnvFile(filePath) {
  const env = {};
  if (!fs.existsSync(filePath)) return env;
  const content = fs.readFileSync(filePath, 'utf-8');
  for (const line of content.split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const match = trimmed.match(/^([^=]+)=(.*)$/);
    if (match) {
      const key = match[1].trim();
      let val = match[2].trim();
      // Remove surrounding quotes if present
      if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
        val = val.slice(1, -1);
      }
      env[key] = val;
    }
  }
  return env;
}

const backendEnv = loadEnvFile(envFile);

// Merge into process.env so any child process inherits these variables
for (const [k, v] of Object.entries(backendEnv)) {
  if (v && !process.env[k]) {
    process.env[k] = v;
  }
}

// ── PATH setup (Bun + ADB) ───────────────────────────────────────────────────
const bunDir = path.join(os.homedir(), '.bun', 'bin');
if (fs.existsSync(bunDir) && !process.env.PATH?.includes(bunDir)) {
  process.env.PATH = `${bunDir}:${process.env.PATH || ''}`;
}
const adbDir = path.join(os.homedir(), 'Library', 'Android', 'sdk', 'platform-tools');
if (fs.existsSync(adbDir) && !process.env.PATH?.includes(adbDir)) {
  process.env.PATH = `${adbDir}:${process.env.PATH || ''}`;
}

// ── Colors ───────────────────────────────────────────────────────────────────
const c = {
  reset: '\x1b[0m', bold: '\x1b[1m', dim: '\x1b[2m',
  green: '\x1b[32m', yellow: '\x1b[33m', cyan: '\x1b[36m',
  red: '\x1b[31m', magenta: '\x1b[35m',
};

const log = (tag, color, msg) =>
  console.log(`${color}${c.bold}[${tag}]${c.reset} ${msg}`);

console.log(`\n${c.bold}${c.green}
=====================================================
  🌱 KisaanBandhu – Mobile Development Runner
=====================================================${c.reset}\n`);

// ── Display Active API Credentials ───────────────────────────────────────────
console.log(`${c.bold}Loaded Backend Credentials (.env):${c.reset}`);
const geminiKey = backendEnv.GEMINI_API_KEY || process.env.GEMINI_API_KEY || '';
const mekoKey = backendEnv.MEKO_API_KEY || process.env.MEKO_API_KEY;
const mekoDatapack = backendEnv.MEKO_DATAPACK_ID || process.env.MEKO_DATAPACK_ID;
const twilioNumber = backendEnv.TWILIO_PHONE_NUMBER || process.env.TWILIO_PHONE_NUMBER;
const vapiKey = backendEnv.VAPI_PRIVATE_API_KEY || process.env.VAPI_PRIVATE_API_KEY;
const vapiPhone = backendEnv.VAPI_PHONE_NUMBER_ID || process.env.VAPI_PHONE_NUMBER_ID;

console.log(`  • Gemini API:      ${geminiKey ? `${c.green}✓ ACTIVE${c.reset} (Key: ${geminiKey.substring(0, 8)}...)` : `${c.yellow}⚠️ Not configured (Offline RAG fallback)${c.reset}`}`);
console.log(`  • Meko Memory:     ${mekoKey ? `${c.green}✓ ACTIVE${c.reset} (Datapack: ${mekoDatapack ? mekoDatapack.substring(0, 8) + '...' : 'default'})` : `${c.dim}ℹ In-memory fallback${c.reset}`}`);
console.log(`  • Twilio Calling:  ${twilioNumber ? `${c.green}✓ ACTIVE${c.reset} (${twilioNumber})` : `${c.dim}ℹ Not configured${c.reset}`}`);
console.log(`  • Vapi Telephony:  ${vapiKey ? (vapiPhone ? `${c.green}✓ ACTIVE${c.reset}` : `${c.yellow}ℹ Key set, Phone Number ID pending (Safe preview mode)${c.reset}`) : `${c.dim}ℹ Not configured${c.reset}`}`);
console.log('');

// ── Step 1: Docker Compose (MongoDB) ─────────────────────────────────────────
log('1/5', c.cyan, 'Starting MongoDB & Mongo Express via Docker Compose...');
try {
  const result = spawnSync('docker', ['compose', 'up', '-d'], {
    cwd: rootDir,
    stdio: 'inherit',
    env: process.env,
  });
  if (result.status !== 0) {
    log('WARN', c.yellow, `docker compose exited with code ${result.status}. Continuing anyway...`);
  } else {
    log('✓', c.green, 'MongoDB running at mongodb://localhost:27017');
    log('✓', c.green, 'Mongo Express UI at http://localhost:8081');
  }
} catch (err) {
  log('WARN', c.yellow, `docker compose failed: ${err.message}. Continuing anyway...`);
}

// ── Step 2: Start NestJS backend in background ───────────────────────────────
log('2/5', c.cyan, 'Starting NestJS backend in background (port 3000)...');

let runner = 'bun';
try {
  if (spawnSync('which', ['bun'], { env: process.env }).status !== 0) runner = 'npm';
} catch { runner = 'npm'; }

const backendProcess = spawn(runner, ['run', 'start:dev'], {
  cwd: backendDir,
  stdio: ['ignore', 'pipe', 'pipe'],
  env: {
    ...process.env,
    ...backendEnv,
  },
});

// Pipe backend logs with a prefix so they don't mix with Flutter logs
backendProcess.stdout.on('data', (data) => {
  const lines = data.toString().split('\n').filter(Boolean);
  lines.forEach(line => console.log(`${c.dim}[backend] ${line}${c.reset}`));
});
backendProcess.stderr.on('data', (data) => {
  const lines = data.toString().split('\n').filter(Boolean);
  lines.forEach(line => console.log(`${c.yellow}[backend:err] ${line}${c.reset}`));
});

// ── Step 3: Wait for backend to be ready ─────────────────────────────────────
log('3/5', c.cyan, 'Waiting for backend to be ready on http://127.0.0.1:3000...');

function checkBackend() {
  return new Promise((resolve) => {
    const req = http.get('http://127.0.0.1:3000', { timeout: 1500 }, (res) => {
      res.resume();
      resolve(true);
    });
    req.on('error', () => resolve(false));
    req.on('timeout', () => { req.destroy(); resolve(false); });
  });
}

async function waitForBackend(maxWaitMs = 60000, intervalMs = 1500) {
  const deadline = Date.now() + maxWaitMs;
  let dots = 0;
  while (Date.now() < deadline) {
    const ready = await checkBackend();
    if (ready) return true;
    process.stdout.write(`\r${c.dim}  Waiting for backend${'.'.repeat((dots++ % 3) + 1)}   ${c.reset}`);
    await new Promise(r => setTimeout(r, intervalMs));
  }
  process.stdout.write('\n');
  return false;
}

const backendReady = await waitForBackend();
process.stdout.write('\n');

if (backendReady) {
  log('✓', c.green, 'Backend is ready on http://127.0.0.1:3000');
} else {
  log('WARN', c.yellow, 'Backend did not respond within 60s. Continuing anyway — check backend logs above.');
}

// ── Step 4: ADB reverse tunnel ───────────────────────────────────────────────
log('4/5', c.cyan, 'Configuring ADB reverse tunnel tcp:3000 ↔ tcp:3000...');
try {
  const adbDevices = spawnSync('adb', ['devices'], { encoding: 'utf-8', env: process.env });
  if (adbDevices.status === 0) {
    const lines = (adbDevices.stdout || '')
      .split('\n')
      .filter(l => l.trim() && !l.startsWith('List of devices'));

    const authorizedDevice = lines.find(l => l.includes('\tdevice'));
    const unauthorizedDevice = lines.find(l => l.includes('unauthorized'));

    if (authorizedDevice) {
      const rev = spawnSync('adb', ['reverse', 'tcp:3000', 'tcp:3000'], { env: process.env });
      if (rev.status === 0) {
        log('✓', c.green, 'ADB reverse tunnel active: Phone → 127.0.0.1:3000 → Mac backend');
      } else {
        log('WARN', c.yellow, 'ADB reverse failed. Backend may not be reachable on device.');
      }
    } else if (unauthorizedDevice) {
      log('WARN', c.yellow, 'Android device connected but UNAUTHORIZED.');
      log('WARN', c.yellow, '→ Check your phone for an "Allow USB debugging?" dialog and tap Allow.');
      log('WARN', c.yellow, '→ Then run: npm run adb:reverse');
    } else {
      log('INFO', c.dim,  'No Android device connected via USB. ADB reverse skipped.');
      log('INFO', c.dim,  '→ Connect your phone and run: npm run adb:reverse');
    }
  } else {
    log('WARN', c.yellow, 'ADB not available. Skipping reverse tunnel.');
  }
} catch {
  log('WARN', c.yellow, 'ADB not found in PATH. Skipping reverse tunnel.');
}

// ── Step 5: Flutter run ───────────────────────────────────────────────────────
log('5/5', c.magenta, 'Launching Flutter app...\n');

// Read dart-defines from env or local config
const mapboxToken = process.env.MAPBOX_ACCESS_TOKEN || backendEnv.MAPBOX_ACCESS_TOKEN || '';
const googlePlacesKey = process.env.GOOGLE_PLACES_API_KEY || backendEnv.GOOGLE_PLACES_API_KEY || '';

const dartDefines = [
  mapboxToken ? `--dart-define=MAPBOX_ACCESS_TOKEN=${mapboxToken}` : null,
  googlePlacesKey ? `--dart-define=GOOGLE_PLACES_API_KEY=${googlePlacesKey}` : null,
  geminiKey ? `--dart-define=GEMINI_API_KEY=${geminiKey}` : null,
  `--dart-define=BACKEND_URL=http://127.0.0.1:3000`,
].filter(Boolean);

const flutterProcess = spawn('flutter', ['run', ...dartDefines], {
  cwd: mobileDir,
  stdio: 'inherit',
  env: process.env,
});

// ── Cleanup: kill backend when Flutter exits ──────────────────────────────────
function cleanup(signal) {
  console.log(`\n${c.yellow}${c.bold}Shutting down all services...${c.reset}`);
  try { backendProcess.kill('SIGINT'); } catch {}
  process.exit(0);
}

process.on('SIGINT', cleanup);
process.on('SIGTERM', cleanup);

flutterProcess.on('exit', (code) => {
  console.log(`\n${c.yellow}Flutter exited. Stopping backend...${c.reset}`);
  try { backendProcess.kill('SIGINT'); } catch {}
  process.exit(code || 0);
});

backendProcess.on('exit', (code) => {
  if (code !== 0 && code !== null) {
    log('ERROR', c.red, `Backend process crashed with code ${code}. Check logs above.`);
  }
});
