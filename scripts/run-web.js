import { spawn } from 'node:child_process';
import path from 'node:path';
import fs from 'node:fs';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const mobileDir = path.resolve(__dirname, '../apps/mobile');

console.log('\x1b[33m[OffMesh Web]\x1b[0m Initializing web runtime environment on port 3002...');

// Wait if flutter lockfile is held by mobile compiler
async function waitForLock() {
  const lockPath = path.join(process.env.USERPROFILE || '', 'flutter_sdk', 'bin', 'cache', 'lockfile');
  let waitCount = 0;
  while (fs.existsSync(lockPath) && waitCount < 30) {
    await new Promise(r => setTimeout(r, 1000));
    waitCount++;
  }
}

async function main() {
  // If launched concurrently via `pnpm dev`, give mobile startup a brief head start to avoid lock collision
  if (process.env.npm_lifecycle_event === 'dev') {
    console.log('\x1b[33m[OffMesh Web]\x1b[0m Coordinating startup with mobile emulator process...');
    await new Promise(r => setTimeout(r, 7000));
  }
  await waitForLock();

  console.log('\x1b[33m[OffMesh Web]\x1b[0m Launching OffMesh Web app on Chrome (http://localhost:3002)...');

  const flutterProcess = spawn('flutter', ['run', '-d', 'chrome', '--web-port', '3002', '--web-hostname', '0.0.0.0'], {
    cwd: mobileDir,
    stdio: 'inherit',
    shell: true,
  });

  flutterProcess.on('exit', (code) => {
    console.log(`\x1b[33m[OffMesh Web]\x1b[0m Web session finished (code ${code})`);
  });

  flutterProcess.on('error', (err) => {
    console.error(`\x1b[31m[OffMesh Web Error]\x1b[0m ${err.message}`);
  });
}

main();
