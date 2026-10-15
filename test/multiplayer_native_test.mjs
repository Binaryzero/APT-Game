// Run from any directory: node path/to/game-trading-card/test/multiplayer_native_test.mjs
// Set GODOT_BIN when Godot is not installed on PATH or in /Applications/Godot.app.
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { access } from 'node:fs/promises';
import { constants } from 'node:fs';
import { createServer } from 'node:http';
import { delimiter, join } from 'node:path';
import { fileURLToPath } from 'node:url';
const serverSource = process.env.GAME_CARD_SERVER_SOURCE;
if (!serverSource) throw new Error('Set GAME_CARD_SERVER_SOURCE to the matching Sandbox game-card-server/src/server.mjs');
const { BUILD, createCardServer } = await import((await import('node:url')).pathToFileURL(serverSource).href);

const project = fileURLToPath(new URL('../', import.meta.url));
const candidates = process.env.GODOT_BIN ? [process.env.GODOT_BIN] : [
  ...(process.env.PATH || '').split(delimiter).flatMap(directory => ['godot', 'godot4'].map(name => join(directory, name))),
  '/Applications/Godot.app/Contents/MacOS/Godot',
];
let godot;
for (const candidate of candidates) {
  try { await access(candidate, constants.X_OK); godot = candidate; break; } catch { /* Try the next installed runtime. */ }
}
assert(godot, 'Godot runtime was not found. Set GODOT_BIN to the Godot executable.');

let bootstrapMode = 'ready';
const server = createServer(async (request, response) => {
  response.setHeader('Content-Type', 'application/json');
  if (request.url === '/test/bootstrap-mode' && request.method === 'POST') {
    const chunks = [];
    for await (const chunk of request) chunks.push(chunk);
    const mode = Buffer.concat(chunks).toString();
    if (['ready', 'unavailable', 'moved'].includes(mode)) {
      bootstrapMode = mode;
      response.end('{}');
      return;
    }
  }
  if (request.url === '/multiplayer/bootstrap.json') {
    if (bootstrapMode === 'unavailable') {
      response.writeHead(503);
      response.end('{"error":"temporarily_unavailable"}');
      return;
    }
    response.end(JSON.stringify({ version: 1, build: BUILD, signalingUrl: bootstrapMode === 'moved' ? 'ws://127.0.0.1:1/ws' : '/ws', iceTransportPolicy: 'all' }));
    return;
  }
  response.writeHead(404);
  response.end('{}');
});
const game = createCardServer({ server, production: true, origins: ['https://game.example'], graceMs: 10000, turnMs: 30000, sweepMs: 20, idleMs: 0 });
try {
  const port = await game.listen();
  const { GAME_MULTIPLAYER_SIGNALING_URL: _override, GAME_MULTIPLAYER_BOOTSTRAP_URL: _bootstrapOverride, GAME_MULTIPLAYER_DISCOVERY_URL: _managedOverride, ...environment } = process.env;
  const child = spawn(godot, ['--headless', '--path', project, '--script', 'res://test/multiplayer_native_test.gd'], {
    stdio: ['ignore', 'pipe', 'pipe'],
    env: {
      ...environment,
      GAME_MULTIPLAYER_TEST_SIGNALING_URL: `ws://127.0.0.1:${port}/ws`,
      GAME_MULTIPLAYER_TEST_PREVIEW_URL: `http://127.0.0.1:${port}/`,
      GAME_MULTIPLAYER_TEST_SESSION: `native-test-${randomUUID()}`,
    },
  });
  let output = '';
  const capture = (stream, destination) => stream.on('data', chunk => {
    destination.write(chunk);
    output = (output + chunk.toString()).slice(-65536);
  });
  capture(child.stdout, process.stdout); capture(child.stderr, process.stderr);
  let timedOut = false;
  const timeout = setTimeout(() => { timedOut = true; child.kill('SIGKILL'); }, 60000);
  const result = await new Promise((resolve, reject) => {
    child.once('error', reject);
    child.once('close', (code, signal) => resolve({ code, signal }));
  }).finally(() => clearTimeout(timeout));
  assert(!timedOut, 'Native multiplayer acceptance exceeded its 60-second deadline.');
  assert.equal(result.code, 0, `Godot native multiplayer acceptance failed (${result.signal || result.code}).`);
  assert(output.includes('[MULTIPLAYER_NATIVE_PASS]'), 'Godot did not complete the native multiplayer acceptance checks.');
  assert.equal(game.rooms.size, 0, 'Leaving both native clients removes the server room.');
} finally {
  await game.close();
}
