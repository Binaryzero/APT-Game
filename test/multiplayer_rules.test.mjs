import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import '../multiplayer/rules.js';
const { Match, CARDS } = globalThis.EmberpanRules;
const roster = (count) => Array.from({ length: count }, (_, i) => ({ id: i + 1, name: `Chef ${i + 1}` }));
const make = (count = 2) => new Match(roster(count), { now: 1000, random: () => 0.5 });
let command = 0;
const act = (m, actor, action) => m.apply(actor, { id: String(++command), revision: m.revision, ...action }, 1001);
const give = (m, p, card) => { const c = { id: ++m.uid, card }; p.hand.push(c); p.mana = 8; return c.id; };

test('native card costs and targeting stay aligned with authoritative rules', () => {
  assert.deepEqual(JSON.parse(readFileSync(new URL('../multiplayer/cards.json', import.meta.url))), CARDS,
    'Regenerate native metadata with node scripts/generate_multiplayer_cards.mjs');
});

test('snapshots expose only recipient hand, never deck order or authoritative references', () => {
  const m = make(4);
  for (const own of m.players) {
    const view = m.snapshot(own.id);
    for (const p of view.players) { assert.equal('hand' in p, p.id === own.id); assert.equal('deck' in p, false); }
    view.players[0].health = 999;
    assert.equal(m.players[0].health, 24);
  }
  assert.throws(() => make(1), /invalid_roster/);
  assert.throws(() => make(5), /invalid_roster/);
});

test('ownership, revisions, duplicates and target validation reject without state mutation', () => {
  const m = make(), p = m.players[0];
  const id = give(m, p, 'precise_chop');
  const before = JSON.stringify(m.snapshot(1));
  assert.equal(act(m, 2, { kind: 'play', card: id }).code, 'not_your_turn');
  assert.equal(act(m, 1, { kind: 'play', card: id, targetPlayer: 1 }).code, 'invalid_target');
  assert.equal(act(m, 1, { kind: 'play', card: 999 }).code, 'invalid_card');
  assert.equal(act(m, 1, { kind: 'play', card: id, targetPlayer: 2, targetUnit: 999 }).code, 'invalid_target');
  assert.equal(JSON.stringify(m.snapshot(1)), before);
  const action = { kind: 'play', card: id, targetPlayer: 2, id: 'once', revision: m.revision };
  assert.equal(m.apply(1, action, 1001).ok, true);
  assert.equal(m.players[1].health, 22);
  assert.equal(m.apply(1, action, 1001).code, 'duplicate_action');
  assert.equal(m.apply(1, { ...action, id: 'stale' }, 1001).code, 'stale_action');
  assert.equal(m.players[1].health, 22);
});

test('units require mana and board room, enter exhausted, then obey guard and simultaneous combat', () => {
  const m = make(), [p, rival] = m.players;
  const id = give(m, p, 'pan_paladin'); p.mana = 0;
  assert.equal(act(m, 1, { kind: 'play', card: id }).code, 'not_enough_mana');
  p.mana = 8; assert.equal(act(m, 1, { kind: 'play', card: id }).ok, true);
  assert.equal(act(m, 1, { kind: 'attack', unit: id, targetPlayer: 2 }).code, 'unit_not_ready');
  act(m, 1, { kind: 'end' }); act(m, 2, { kind: 'end' });
  rival.board = [{ id: ++m.uid, card: 'pan_paladin', attack: 2, health: 4, guard: true, ready: true }];
  assert.equal(act(m, 1, { kind: 'attack', unit: id, targetPlayer: 2 }).code, 'guard_blocks');
  assert.equal(act(m, 1, { kind: 'attack', unit: id, targetPlayer: 2, targetUnit: rival.board[0].id }).ok, true);
  assert.equal(p.board[0].health, 2); assert.equal(rival.board[0].health, 2);
  assert.equal(act(m, 1, { kind: 'attack', unit: id, targetPlayer: 2, targetUnit: rival.board[0].id }).code, 'unit_not_ready');
  while (p.board.length < 4) p.board.push({ id: ++m.uid, card: 'coal_squire', health: 2 });
  const full = give(m, p, 'coal_squire');
  assert.equal(act(m, 1, { kind: 'play', card: full }).code, 'board_full');
});

test('every PvP card has an implemented effect and correct target semantics', () => {
  for (const [card, definition] of Object.entries(CARDS)) {
    const m = make(3), [p, rival, untouched] = m.players;
    p.health = 18; rival.board = [{ id: 100, card: 'pan_paladin', health: 4, attack: 2, guard: true }];
    p.board = [{ id: 101, card: 'coal_squire', health: 2, attack: 1, ready: true }];
    const id = give(m, p, card);
    const action = { kind: 'play', card: id };
    if (definition.target) action.targetPlayer = definition.target === 'friend' ? 1 : 2;
    if (definition.target === 'friend') action.targetUnit = 101;
    assert.equal(act(m, 1, action).ok, true, card);
    assert.equal(p.mana, 8 - definition.cost);
    assert.equal(untouched.health, 24, 'effects never hit unrelated players');
    if (definition.effect === 'buff') assert.equal(p.board[0].attack, 3);
    if (definition.effect === 'damage') assert.equal(rival.health, 22);
    if (definition.effect === 'area') assert.equal(rival.board[0].health, 2);
    if (definition.effect === 'heal') assert.equal(p.health, 21);
    if (definition.effect === 'armor') assert.equal(p.armor, definition.value);
  }
});

test('guest reconnect preserves hidden state; forfeit advances turns and determines winner', () => {
  const m = make(3), original = structuredClone(m.players[1]);
  m.setConnected(2, false); m.setConnected(2, true);
  assert.deepEqual(m.players[1], original);
  assert.equal(m.forfeit(1, 1001), true); assert.equal(m.snapshot(2).active, 2);
  assert.equal(m.forfeit(3, 1001), true); assert.equal(m.status, 'ended'); assert.equal(m.winner, 2);
  assert.equal(m.forfeit(3, 1001), false);
});

test('timer skips idle turns and pauses disconnected active seat without expiring on resume', () => {
  const m = make();
  m.setConnected(1, false);
  assert.equal(m.tick(60000), false);
  m.setConnected(1, true);
  assert(m.deadline > 60000);
  assert.equal(m.tick(m.deadline + 1), true);
  assert.equal(m.snapshot(1).active, 2);
  const deadline = m.deadline;
  assert.equal(m.tick(deadline + 1, true), false);
});

for (const count of [2, 3, 4]) test(`${count}-player complete matches terminate through fatigue and skip eliminated seats`, () => {
  const m = make(count);
  let turns = 0;
  while (m.status === 'playing' && turns++ < 500) {
    const active = m.players[m.current];
    assert(active.alive);
    assert.equal(act(m, active.id, { kind: 'end' }).ok, true);
  }
  assert(turns < 500); assert.equal(m.status, 'ended');
  assert.equal(m.players.filter((p) => p.alive).length, 1);
});
