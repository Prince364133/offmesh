import { spawn, execSync } from 'node:child_process';
import path from 'node:path';
import fs from 'node:fs';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const mobileDir = path.resolve(__dirname, '../apps/mobile');

console.log('\x1b[32m[OffMesh Mobile]\x1b[0m Initializing mobile runtime environment...');

// Remove stale flutter lockfile if exists
function clearFlutterLock() {
  const possiblePaths = [
    path.join(process.env.USERPROFILE || '', 'flutter_sdk', 'bin', 'cache', 'lockfile'),
    path.join(process.env.LOCALAPPDATA || '', 'flutter', 'bin', 'cache', 'lockfile'),
  ];
  for (const lockPath of possiblePaths) {
    try {
      if (fs.existsSync(lockPath)) {
        fs.unlinkSync(lockPath);
      }
    } catch {}
  }
}

// Find ADB attached devices
function getAdbDevices() {
  try {
    const output = execSync('adb devices', { encoding: 'utf8' });
    const lines = output.trim().split('\n').slice(1);
    const devices = [];
    for (const line of lines) {
      const parts = line.trim().split(/\s+/);
      if (parts.length >= 2 && parts[1] === 'device') {
        devices.push(parts[0]);
      }
    }
    return devices;
  } catch {
    return [];
  }
}

// Check if emulator is fully booted
function isBootCompleted(deviceId) {
  try {
    const res = execSync(`adb -s ${deviceId} shell getprop sys.boot_completed`, {
      encoding: 'utf8',
      timeout: 3000,
    }).trim();
    return res === '1';
  } catch {
    return false;
  }
}

// Locate emulator binary
function getEmulatorBinPath() {
  const localAppData = process.env.LOCALAPPDATA || '';
  const defaultPath = path.join(localAppData, 'Android', 'Sdk', 'emulator', 'emulator.exe');
  if (fs.existsSync(defaultPath)) return defaultPath;
  return 'emulator';
}

async function main() {
  clearFlutterLock();

  let devices = getAdbDevices();
  let targetId = devices[0];

  if (!targetId) {
    console.log('\x1b[33m[OffMesh Mobile]\x1b[0m No running Android emulator detected. Starting Pixel_7_API_34...');
    const emulatorBin = getEmulatorBinPath();

    try {
      const emuProc = spawn(emulatorBin, ['-avd', 'Pixel_7_API_34', '-netdelay', 'none', '-no-snapshot-load'], {
        detached: true,
        stdio: 'ignore',
        windowsHide: false,
      });
      emuProc.unref();
    } catch (e) {
      console.warn('\x1b[33m[OffMesh Mobile Warning]\x1b[0m Failed to spawn emulator directly, trying flutter emulators:', e.message);
      try {
        spawn('flutter', ['emulators', '--launch', 'Pixel_7_API_34'], {
          detached: true,
          stdio: 'ignore',
          shell: true,
        }).unref();
      } catch {}
    }

    console.log('\x1b[32m[OffMesh Mobile]\x1b[0m Waiting for Android emulator to connect (up to 45s)...');
    const startTime = Date.now();
    while (Date.now() - startTime < 45000) {
      await new Promise(r => setTimeout(r, 3000));
      devices = getAdbDevices();
      if (devices.length > 0) {
        targetId = devices[0];
        break;
      }
    }
  }

  if (targetId) {
    console.log(`\x1b[32m[OffMesh Mobile]\x1b[0m Android emulator connected: \x1b[36m${targetId}\x1b[0m`);
    // Wait for boot completion
    let booted = false;
    for (let i = 0; i < 15; i++) {
      if (isBootCompleted(targetId)) {
        booted = true;
        break;
      }
      await new Promise(r => setTimeout(r, 2000));
    }
    if (booted) {
      console.log(`\x1b[32m[OffMesh Mobile]\x1b[0m System boot completed on \x1b[36m${targetId}\x1b[0m`);
    }
  } else {
    console.log('\x1b[33m[OffMesh Mobile Warning]\x1b[0m Android emulator not available. Checking for Windows desktop or Chrome fallback...');
    try {
      const flutterDevicesOut = execSync('flutter devices --machine', { encoding: 'utf8', timeout: 8000 });
      const flDevices = JSON.parse(flutterDevicesOut);
      const fallback = flDevices.find(d => d.id === 'windows' || d.id === 'chrome');
      if (fallback) {
        targetId = fallback.id;
        console.log(`\x1b[33m[OffMesh Mobile Notice]\x1b[0m Falling back to: \x1b[36m${fallback.name} (${fallback.id})\x1b[0m`);
      }
    } catch {
      targetId = 'android';
    }
  }

  clearFlutterLock();

  const finalTarget = targetId || 'emulator-5554';
  console.log(`\x1b[32m[OffMesh Mobile]\x1b[0m Launching OffMesh Flutter application on \x1b[36m${finalTarget}\x1b[0m...`);

  const flutterProcess = spawn('flutter', ['run', '-d', finalTarget], {
    cwd: mobileDir,
    stdio: 'inherit',
    shell: true,
  });

  flutterProcess.on('exit', (code) => {
    console.log(`\x1b[32m[OffMesh Mobile]\x1b[0m Flutter session finished (code ${code})`);
  });

  flutterProcess.on('error', (err) => {
    console.error(`\x1b[31m[OffMesh Mobile Error]\x1b[0m ${err.message}`);
  });
}

main();
