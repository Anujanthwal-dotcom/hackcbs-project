#!/usr/bin/env node

import { spawn, spawnSync } from 'child_process';
import path from 'path';
import os from 'os';
import fs from 'fs';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, '..');
const backendDir = path.join(rootDir, 'backend');

// Ensure Bun and Android platform-tools PATH are available
const bunDir = path.join(os.homedir(), '.bun', 'bin');
if (fs.existsSync(bunDir) && !process.env.PATH?.includes(bunDir)) {
  process.env.PATH = `${bunDir}:${process.env.PATH || ''}`;
}

const adbDir = path.join(os.homedir(), 'Library', 'Android', 'sdk', 'platform-tools');
if (fs.existsSync(adbDir) && !process.env.PATH?.includes(adbDir)) {
  process.env.PATH = `${adbDir}:${process.env.PATH || ''}`;
}

const colors = {
  reset: '\x1b[0m',
  bold: '\x1b[1m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  cyan: '\x1b[36m',
  red: '\x1b[31m',
  dim: '\x1b[2m',
};

console.log(`${colors.bold}${colors.green}
=====================================================
  🌱 KisaanBandhu Full-Stack Development Services
=====================================================${colors.reset}\n`);

// 1. Start Docker Compose (MongoDB + Mongo Express)
console.log(`${colors.cyan}[1/3] Starting MongoDB & Mongo Express containers...${colors.reset}`);
try {
  const composeResult = spawnSync('docker', ['compose', 'up', '-d'], {
    cwd: rootDir,
    stdio: 'inherit',
    env: process.env,
  });

  if (composeResult.status !== 0) {
    console.warn(`${colors.yellow}⚠️  Warning: docker compose exited with code ${composeResult.status}.${colors.reset}`);
  } else {
    console.log(`${colors.green}✓ Docker services running:${colors.reset}`);
    console.log(`  - MongoDB: ${colors.bold}mongodb://localhost:27017${colors.reset}`);
    console.log(`  - Mongo Express UI: ${colors.bold}http://localhost:8081${colors.reset}`);
  }
} catch (err) {
  console.error(`${colors.red}❌ Failed to run docker compose: ${err.message}${colors.reset}`);
}

// 2. Check and configure ADB reverse port forwarding for USB debugging
console.log(`\n${colors.cyan}[2/3] Checking ADB USB debugging device...${colors.reset}`);
try {
  const adbCheck = spawnSync('adb', ['devices'], { encoding: 'utf-8' });
  if (adbCheck.status === 0) {
    const lines = adbCheck.stdout.split('\n').filter(line => line.trim() && !line.startsWith('List of devices'));
    if (lines.length > 0) {
      const adbRev = spawnSync('adb', ['reverse', 'tcp:3000', 'tcp:3000']);
      if (adbRev.status === 0) {
        console.log(`${colors.green}✓ ADB reverse enabled: tcp:3000 <-> tcp:3000 for mobile USB debugging.${colors.reset}`);
      } else {
        console.log(`${colors.yellow}ℹ ADB reverse returned non-zero code. Mobile app can use standard IP.${colors.reset}`);
      }
    } else {
      console.log(`${colors.dim}ℹ No Android device attached via USB (adb reverse skipped).${colors.reset}`);
    }
  } else {
    console.log(`${colors.dim}ℹ ADB not available or not running (adb reverse skipped).${colors.reset}`);
  }
} catch {
  console.log(`${colors.dim}ℹ ADB command not found in PATH (adb reverse skipped).${colors.reset}`);
}

// 3. Determine runner (bun vs npm)
let runner = 'bun';
try {
  const checkBun = spawnSync('which', ['bun'], { env: process.env });
  if (checkBun.status !== 0) {
    runner = 'npm';
  }
} catch {
  runner = 'npm';
}

console.log(`\n${colors.cyan}[3/3] Starting NestJS Backend with ${runner}...${colors.reset}`);
console.log(`${colors.dim}API server will run on http://localhost:3000\n${colors.reset}`);

const backendProcess = spawn(runner, ['run', 'start:dev'], {
  cwd: backendDir,
  stdio: 'inherit',
  env: process.env,
});

function cleanup() {
  console.log(`\n${colors.yellow}Shutting down backend process...${colors.reset}`);
  backendProcess.kill('SIGINT');
  process.exit(0);
}

process.on('SIGINT', cleanup);
process.on('SIGTERM', cleanup);

backendProcess.on('exit', (code) => {
  if (code !== 0 && code !== null) {
    console.log(`${colors.red}Backend exited with code ${code}${colors.reset}`);
  }
  process.exit(code || 0);
});

