// Browser/Node-compatible host rules. No networking, rendering or campaign save access.
(() => {
  'use strict';
  const CARDS = Object.freeze({
    mise_the_thousand_handed: { cost: 6, attack: 4, health: 7, aura: 'low_cost_engine' },
    the_sovereign_cleaver: { cost: 7, effect: 'cleave', value: 5, target: 'hero' },
    bell_of_the_last_service: { cost: 8, effect: 'bell', value: 3, heal: 8 },
    coal_squire: { cost: 1, attack: 1, health: 2, effect: 'armor', value: 1 },
    pan_paladin: { cost: 2, attack: 2, health: 4, guard: true },
    pepper_mage: { cost: 3, attack: 3, health: 2, effect: 'damage', value: 2, target: 'hero' },
    broth_elemental: { cost: 3, attack: 2, health: 4, effect: 'heal', value: 3 },
    truffle_knight: { cost: 5, attack: 5, health: 6, guard: true },
    precise_chop: { cost: 1, effect: 'damage', value: 2, target: 'enemy' },
    searing_arc: { cost: 3, effect: 'area', value: 2, target: 'hero' },
    mise_en_place: { cost: 2, effect: 'draw', value: 2 },
    kitchen_guard: { cost: 2, effect: 'armor', value: 5 },
    seasoned_strike: { cost: 2, effect: 'buff', value: 2, target: 'friend' },
  });
  const DECK = ['coal_squire', 'coal_squire', 'coal_squire', 'coal_squire', 'pan_paladin', 'pan_paladin', 'pan_paladin', 'pepper_mage', 'broth_elemental', 'truffle_knight', 'precise_chop', 'precise_chop', 'precise_chop', 'searing_arc', 'mise_en_place', 'kitchen_guard', 'kitchen_guard', 'seasoned_strike'];
  const STARTERS = Object.freeze({
    balanced: [...DECK],
    aggro: ['coal_squire','coal_squire','coal_squire','coal_squire','pepper_mage','pepper_mage','pepper_mage','pan_paladin','pan_paladin','precise_chop','precise_chop','precise_chop','searing_arc','searing_arc','mise_en_place','mise_en_place','seasoned_strike','seasoned_strike'],
    guard: ['coal_squire','coal_squire','pan_paladin','pan_paladin','pan_paladin','pan_paladin','broth_elemental','broth_elemental','truffle_knight','truffle_knight','precise_chop','precise_chop','mise_en_place','mise_en_place','kitchen_guard','kitchen_guard','seasoned_strike','searing_arc'],
  });
  const HEROES = ['chef_sama', 'picklemancer', 'mold_monarch', 'ember_butcher', 'banquet_tyrant'];
  const LEGENDARIES = ['mise_the_thousand_handed', 'the_sovereign_cleaver', 'bell_of_the_last_service'];
  const DEFAULT_LOADOUT = { starter: 'balanced', hero: 'chef_sama', legendary: LEGENDARIES[0] };
  const validLoadout = (v) => v && typeof v === 'object' && !Array.isArray(v) && Object.keys(v).length === 3 && ['starter', 'hero', 'legendary'].every(key => typeof v[key] === 'string') && Object.hasOwn(STARTERS, v.starter) && HEROES.includes(v.hero) && LEGENDARIES.includes(v.legendary);
  const copy = (value) => JSON.parse(JSON.stringify(value));
  class Match {
    constructor(members, { random = Math.random, now = Date.now(), turnMs = 45000 } = {}) {
      if (!Array.isArray(members) || members.length < 2 || members.length > 4 || new Set(members.map((m) => m.id)).size !== members.length || members.some((m) => !Number.isSafeInteger(m.id))) throw new Error('invalid_roster');
      this.uid = 0; this.revision = 0; this.turn = 0; this.current = -1;
      this.status = 'playing'; this.winner = null; this.turnMs = turnMs; this.lastTick = now;
      this.seen = new Map(); this.last = { kind: 'start', actor: 1 };
      this.players = members.map((m) => {
        const loadout = m.loadout ?? DEFAULT_LOADOUT;
        if (!validLoadout(loadout)) throw new Error('invalid_loadout');
        const deck = [...STARTERS[loadout.starter], loadout.legendary];
        for (let i = deck.length - 1; i > 0; i--) { const j = Math.floor(random() * (i + 1)); [deck[i], deck[j]] = [deck[j], deck[i]]; }
        const player = { id: m.id, name: m.name, loadout: copy(loadout), hero: loadout.hero, health: 24, armor: 0, mana: 0, maxMana: 0, fatigue: 0, deck, hand: [], board: [], alive: true, connected: true };
        for (let i = 0; i < 4; i++) this.draw(player);
        return player;
      });
      this.advance(now);
    }
    draw(player) {
      if (!player.deck.length) { this.damageHero(player, ++player.fatigue); return; }
      const card = { id: ++this.uid, card: player.deck.pop() };
      if (player.hand.length < 8) player.hand.push(card);
    }
    damageHero(player, amount) {
      const absorbed = Math.min(player.armor, amount);
      player.armor -= absorbed; player.health -= amount - absorbed;
    }
    settle() {
      for (const p of this.players) {
        p.board = p.board.filter((u) => u.health > 0);
        if (p.health <= 0) { p.health = 0; p.alive = false; p.board = []; }
      }
      const living = this.players.filter((p) => p.alive);
      if (living.length <= 1) { this.status = 'ended'; this.winner = living[0]?.id ?? null; }
    }
    advance(now) {
      // Fatigue can eliminate several players while advancing; bounded by roster size.
      for (let i = 0; i < this.players.length && this.status === 'playing'; i++) {
        this.current = (this.current + 1) % this.players.length;
        const p = this.players[this.current];
        if (!p.alive) continue;
        this.turn++;
        p.maxMana = Math.min(8, p.maxMana + 1); p.mana = p.maxMana;
        for (const u of p.board) u.ready = true;
        this.draw(p); this.settle();
        this.deadline = now + this.turnMs;
        if (p.alive) break;
      }
    }
    snapshot(id) {
      return copy({ revision: this.revision, status: this.status, winner: this.winner, turn: this.turn, active: this.players[this.current].id, deadline: this.deadline, last: this.last,
        players: this.players.map((p) => ({ id: p.id, name: p.name, hero: p.hero, health: p.health, armor: p.armor, mana: p.mana, maxMana: p.maxMana, alive: p.alive, connected: p.connected, board: p.board, handCount: p.hand.length, deckCount: p.deck.length, ...(p.id === id ? { hand: p.hand } : {}) })) });
    }
    setConnected(id, value) {
      const p = this.players.find((p) => p.id === id);
      if (!p || p.connected === value) return false;
      p.connected = value; this.revision++; return true;
    }
    forfeit(id, now = Date.now()) {
      const p = this.players.find((p) => p.id === id);
      if (!p?.alive || this.status !== 'playing') return false;
      p.health = 0; this.settle(); this.last = { kind: 'forfeit', actor: id }; this.revision++;
      if (this.status === 'playing' && this.players[this.current].id === id) this.advance(now);
      return true;
    }
    tick(now = Date.now(), paused = false) {
      if (this.status !== 'playing') return false;
      if (paused || !this.players[this.current].connected) this.deadline += Math.max(0, now - this.lastTick);
      this.lastTick = now;
      if (now < this.deadline) return false;
      this.last = { kind: 'timeout', actor: this.players[this.current].id };
      this.advance(now); this.revision++; return true;
    }
    apply(actor, action, now = Date.now()) {
      const error = (code) => ({ ok: false, code });
      if (!action || typeof action !== 'object' || Array.isArray(action) || typeof action.id !== 'string' || action.id.length < 1 || action.id.length > 80) return error('invalid_action');
      const key = `${actor}:${action.id}`;
      if (this.seen.has(key)) return error('duplicate_action');
      if (action.revision !== this.revision) return error('stale_action');
      if (this.status !== 'playing') return error('match_ended');
      const p = this.players[this.current];
      if (p.id !== actor || !p.alive || !p.connected) return error('not_your_turn');
      if (now >= this.deadline) return error('turn_expired');
      if (!['play', 'attack', 'end'].includes(action.kind)) return error('invalid_action');
      let card, definition, attacker, targetPlayer, targetUnit;
      if (action.kind === 'play') {
        card = p.hand.find((c) => c.id === action.card);
        if (!card) return error('invalid_card');
        definition = CARDS[card.card];
        if (p.mana < definition.cost) return error('not_enough_mana');
        if (definition.health && p.board.length >= 4) return error('board_full');
      }
      if (action.kind === 'attack') {
        attacker = p.board.find((u) => u.id === action.unit);
        if (!attacker?.ready) return error('unit_not_ready');
      }
      if (attacker || definition?.target) {
        targetPlayer = this.players.find((q) => q.id === action.targetPlayer && q.alive);
        if (!targetPlayer) return error('invalid_target');
        targetUnit = targetPlayer.board.find((u) => u.id === action.targetUnit);
        if (action.targetUnit !== undefined && action.targetUnit !== null && !targetUnit) return error('invalid_target');
        if (definition?.target === 'friend') {
          if (targetPlayer.id !== actor || !targetUnit) return error('invalid_target');
        } else if (targetPlayer.id === actor) return error('invalid_target');
        if (definition?.target === 'hero' && targetUnit) return error('invalid_target');
        if (attacker && targetPlayer.board.some((u) => u.guard) && !targetUnit?.guard) return error('guard_blocks');
      }
      // Validation is complete. No mutation occurs on any rejection above.
      this.seen.set(key, true);
      if (this.seen.size > 512) this.seen.delete(this.seen.keys().next().value);
      if (action.kind === 'end') this.advance(now);
      if (attacker) {
        attacker.ready = false;
        if (targetUnit) { targetUnit.health -= attacker.attack; attacker.health -= targetUnit.attack; }
        else this.damageHero(targetPlayer, attacker.attack);
      }
      if (card) {
        p.mana -= definition.cost;
        p.hand = p.hand.filter((c) => c.id !== card.id);
        if (definition.health) p.board.push({ id: card.id, card: card.card, attack: definition.attack, health: definition.health, guard: !!definition.guard, ready: false });
        switch (definition.effect) {
          case 'cleave': for (const u of targetPlayer.board) u.health -= definition.value; this.damageHero(targetPlayer, definition.value); break;
          case 'bell': p.health = Math.min(24, p.health + definition.heal); for (const u of p.board) { u.attack += definition.value; u.health += definition.value; u.ready = true; } break;
          case 'armor': p.armor += definition.value; break;
          case 'heal': p.health = Math.min(24, p.health + definition.value); break;
          case 'damage': if (targetUnit) targetUnit.health -= definition.value; else this.damageHero(targetPlayer, definition.value); break;
          case 'area': for (const u of targetPlayer.board) u.health -= definition.value; break;
          case 'draw': for (let i = 0; i < definition.value; i++) this.draw(p); break;
          case 'buff': targetUnit.attack += definition.value; targetUnit.health += definition.value; break;
        }
      }
      if (card && definition.cost <= 2 && p.board.some((u) => u.card === 'mise_the_thousand_handed' && u.health > 0)) { this.draw(p); p.mana = Math.min(p.maxMana, p.mana + 1); }
      this.settle();
      if (this.status === 'playing' && !this.players[this.current].alive) this.advance(now);
      this.revision++; this.last = { kind: action.kind, actor, ...(card ? { card: card.card } : {}) };
      return { ok: true, revision: this.revision };
    }
  }
  globalThis.EmberpanRules = { Match, CARDS, DECK, STARTERS, HEROES, LEGENDARIES, DEFAULT_LOADOUT, validLoadout };
})();
