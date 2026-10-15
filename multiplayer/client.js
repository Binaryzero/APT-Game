// Godot calls command(JSON) and polls drain(). Gameplay is authoritative on the dedicated WSS server.
(() => {
  'use strict';
  class Client {
    constructor() {
      this.state = { screen: 'setup', status: 'setup', connectionMode: '', connectionStage: '', id: 0, room: null, snapshot: null, error: '' };
      this.dirty = true; this.active = false; this.retry = 0;
      this.timer = setInterval(() => this.tick(), 500);
      this.unload = (event = {}) => {
        this.suspended = !!event.persisted && this.active && !!this.auth?.token;
        this.attempt = (this.attempt || 0) + 1; this.pending = false;
        this.active = false; this.ws?.close();
      };
      this.restore = (event = {}) => {
        if (!event.persisted || !this.suspended || this.disposed) return;
        this.suspended = false;
        return this.command(JSON.stringify({ op: 'resume' }));
      };
      window.addEventListener('pagehide', this.unload);
      window.addEventListener('pageshow', this.restore);
    }
    storage(type, key, value) {
      try { if (value === undefined) return window[type].getItem(key); if (value === null) window[type].removeItem(key); else window[type].setItem(key, value); } catch { /* Private browsing may disable storage. Live sessions still work. */ }
      return null;
    }
    configure(json) {
      this.defaults = JSON.parse(json);
      this.config = { ...this.defaults };
      // This operator-owned value is injected by the game runtime, never read from an invitation or player preferences.
      const injected = window.__MANUS_GAME_MULTIPLAYER__;
      this.hasManagedDiscovery = !!injected && Object.hasOwn(injected, 'bootstrapUrl');
      this.managedBootstrapUrl = this.hasManagedDiscovery ? injected.bootstrapUrl : undefined;
      this.preferenceKey = `emberpan-pvp:${location.pathname}:${this.config.build}`;
      // Old versions exposed endpoint overrides to players. Never reuse those URLs.
      this.storage('localStorage', this.preferenceKey, null);
      this.state.playerName = this.storage('localStorage', `${this.preferenceKey}:name`) || '';
      this.setup();
      this.prepare().then(() => {
        if (this.disposed || this.autoEntryCancelled || this.pending || this.active || !this.state.invitation) return;
        const saved = this.saved();
        const invitation = this.parseInvitation(this.state.invitation);
        this.command(JSON.stringify(saved?.id > 0 && saved.room === invitation.room
          ? { op: 'resume' }
          : { op: 'join', name: this.state.playerName || 'Chef', invitation: this.state.invitation }));
      }).catch(() => { /* Host / Join retries discovery and shows a player-facing error. */ });
    }
    setup() {
      this.state.config = this.config;
      this.state.invitation = location.hash.startsWith('#room=') ? location.href : '';
      this.state.canResume = (this.saved()?.id || 0) > 0;
      this.changed();
    }
    async prepare(refresh = false, room = '') {
      if (!refresh && this.state.service === 'ready') return;
      if (this.preparing) return this.preparing;
      this.state.service = 'checking'; this.changed();
      this.preparing = this.discover(room).then((config) => {
        if (this.disposed) return;
        this.config = config; this.state.config = config;
        this.state.service = 'ready'; this.state.canResume = (this.saved()?.id || 0) > 0;
        this.changed();
      }).catch(() => {
        if (!this.disposed) { this.state.service = 'unavailable'; this.changed(); }
        throw new Error('service_unavailable');
      }).finally(() => { this.preparing = null; });
      return this.preparing;
    }
    async discover(room = '') {
      let config = { ...this.defaults };
      if (this.hasManagedDiscovery || config.bootstrapUrl) {
        let endpoint;
        if (this.hasManagedDiscovery) {
          if (typeof this.managedBootstrapUrl !== 'string' || !this.managedBootstrapUrl) throw new Error('invalid_service_config');
          endpoint = new URL(this.managedBootstrapUrl);
          if (endpoint.protocol !== 'https:' || endpoint.username || endpoint.password || endpoint.hash) throw new Error('invalid_service_config');
          if (room && (typeof room !== 'string' || !/^[a-zA-Z0-9_-]{1,64}$/.test(room))) throw new Error('invalid_invite');
          endpoint.searchParams.set('build', config.build);
          endpoint.searchParams.delete('room'); endpoint.searchParams.delete('mode');
          if (room) endpoint.searchParams.set('room', room);
        } else {
          endpoint = new URL(config.bootstrapUrl, location.href);
          if (endpoint.origin !== new URL(location.href).origin || endpoint.username || endpoint.password || endpoint.hash) throw new Error('invalid_service_config');
        }
        const controller = new AbortController();
        this.discoveryController = controller;
        const timeout = setTimeout(() => controller.abort(), 8000);
        try {
          const response = await fetch(endpoint.href, { cache: 'no-store', credentials: this.hasManagedDiscovery ? 'omit' : 'same-origin',
            ...(this.hasManagedDiscovery ? { mode: 'cors' } : {}), redirect: 'error', signal: controller.signal });
          if (response.ok) {
            const body = await response.text();
            if (body.length > 4096) throw new Error('invalid_service_config');
            const managed = JSON.parse(body);
            if (managed.version !== 1 || managed.build !== config.build) throw new Error('invalid_service_config');
            if (this.hasManagedDiscovery) {
              const service = new URL(managed.signalingUrl);
              const hostname = service.hostname.replace(/\.$/, '');
              const loopback = ['localhost', '[::1]', '[::]', '0.0.0.0'].includes(hostname) || hostname.endsWith('.localhost') || /^127\./.test(hostname);
              if (service.protocol !== 'wss:' || loopback) throw new Error('invalid_service_config');
            }
            config = { ...config, signalingUrl: managed.signalingUrl, iceTransportPolicy: managed.iceTransportPolicy || 'all' };
          } else if (this.hasManagedDiscovery || response.status !== 404 || !config.signalingUrl) throw new Error('service_unavailable');
        } finally { clearTimeout(timeout); if (this.discoveryController === controller) this.discoveryController = null; }
      }
      if (typeof config.signalingUrl !== 'string' || !config.signalingUrl) throw new Error('service_unavailable');
      if (config.signalingUrl.startsWith('/') && !config.signalingUrl.startsWith('//')) {
        const url = new URL(config.signalingUrl, location.href);
        url.protocol = location.protocol === 'https:' ? 'wss:' : 'ws:';
        config.signalingUrl = url.href;
      }
      this.validateUrl(config.signalingUrl);
      if (!['all', 'relay'].includes(config.iceTransportPolicy)) throw new Error('invalid_service_config');
      return config;
    }
    parseInvitation(value) {
      if (typeof value !== 'string' || value.length > 2048) throw new Error('invalid_invite');
      let room, invite;
      if (value.includes('#')) {
        let url;
        try { url = new URL(value); } catch { throw new Error('invalid_invite'); }
        if (!['https:', 'http:'].includes(url.protocol) || url.username || url.password) throw new Error('invalid_invite');
        const params = new URLSearchParams(url.hash.slice(1));
        room = params.get('room'); invite = params.get('invite');
      } else [room, invite] = value.trim().split('.');
      if (!room || !invite || !/^[a-zA-Z0-9_-]{1,64}$/.test(room) || !/^[a-zA-Z0-9_-]{1,256}$/.test(invite)) throw new Error('invalid_invite');
      return { room, invite };
    }
    async begin(auth) {
      if (this.active || this.pending) return;
      this.pending = true;
      const attempt = this.attempt = (this.attempt || 0) + 1;
      this.state.connectionMode = auth.op === 'create' ? 'host' : auth.op === 'join' ? 'join' : 'resume';
      this.state.connectionStage = 'contacting_lobby';
      this.state.screen = 'connecting'; this.state.status = 'connecting'; this.changed();
      try {
        const saved = auth.op === 'resume' ? this.saved() : null;
        if (auth.op === 'resume' && !saved) throw new Error('resume_unavailable');
        if (saved) {
          // A replacement deployment cannot restore a room owned by its predecessor.
          // Finish any initial discovery, then use only the endpoint saved after authentication.
          await this.preparing?.catch(() => {});
          this.config = { ...this.config, signalingUrl: saved.endpoint };
          this.state.config = this.config; this.state.service = 'ready';
        } else {
          await this.preparing?.catch(() => {});
          if (this.disposed || attempt !== this.attempt) return;
          await this.prepare(true, auth.op === 'join' ? auth.room : '');
        }
        if (this.disposed || attempt !== this.attempt) return;
        if (auth.op === 'resume') {
          auth = { op: 'resume', room: saved.room, id: saved.id, token: saved.token };
        } else {
          // Match the service's 24 UTF-16-unit cap without a split surrogate.
          auth.name = String(auth.name || 'Chef').trim().slice(0, 24).replace(/[\uD800-\uDBFF]$/u, '') || 'Chef';
          this.storage('localStorage', `${this.preferenceKey}:name`, auth.name);
        }
        this.open(auth);
      } catch (error) {
        if (attempt !== this.attempt || this.disposed) return;
        this.state.screen = 'setup'; this.state.status = 'setup'; this.state.connectionMode = ''; this.state.connectionStage = '';
        throw error;
      } finally { if (attempt === this.attempt) { this.pending = false; this.changed(); } }
    }
    key(endpoint = this.config.signalingUrl) { return `${this.preferenceKey}:${endpoint}`; }
    saved() {
      try {
        const saved = JSON.parse(this.storage('sessionStorage', this.preferenceKey + ':resume') || this.storage('sessionStorage', this.key()) || 'null');
        if (!saved || !Number.isSafeInteger(saved.id) || saved.id < 1 || typeof saved.room !== 'string' || typeof saved.token !== 'string') return null;
        const endpoint = saved.endpoint || this.config.signalingUrl;
        this.validateUrl(endpoint);
        return { ...saved, endpoint };
      } catch { return null; }
    }
    clearSaved() {
      const saved = this.saved();
      this.storage('sessionStorage', this.preferenceKey + ':resume', null);
      for (const endpoint of new Set([this.config.signalingUrl, saved?.endpoint].filter(Boolean))) {
        this.storage('sessionStorage', this.key(endpoint), null);
        this.storage('sessionStorage', this.key(endpoint) + ':invite', null);
      }
    }
    changed() { this.dirty = true; }
    drain() { if (!this.dirty) return ''; this.dirty = false; return JSON.stringify(this.state); }
    error(code) { this.state.error = code; this.changed(); }
    async command(json) {
      try {
        const c = JSON.parse(json);
        this.state.error = '';
        switch (c.op) {
          case 'host': await this.begin({ op: 'create', name: c.name }); break;
          case 'join': await this.begin({ op: 'join', name: c.name, ...this.parseInvitation(c.invitation) }); break;
          case 'resume': await this.begin({ op: 'resume' }); break;
          case 'start':
            if (this.state.id !== this.state.room?.leader || !this.state.canStart) throw new Error('players_not_ready');
            this.send({ op: 'start' }); break;
          case 'action': this.action(c.action); break;
          case 'loadout': this.send({ op: 'loadout', loadout: c.loadout }); break;
          case 'ready': this.send({ op: 'ready', ready: !this.state.ready }); break;
          case 'rematch': this.send({ op: 'rematch', ready: !this.state.rematch }); break;
          case 'copy':
            if (!navigator.clipboard) throw new Error('copy_unavailable');
            try { await navigator.clipboard.writeText(this.state.invitation); } catch { throw new Error('copy_unavailable'); }
            this.state.inviteCopied = true; break;
          case 'leave': this.clearInvitation(); this.leave(); this.state = { screen: 'setup', status: 'setup', connectionMode: '', connectionStage: '', id: 0, room: null, snapshot: null, error: '', service: this.state.service }; this.setup(); break;
          default: throw new Error('invalid_action');
        }
        this.changed();
      } catch (e) { this.error(e.message); }
    }
    validateUrl(url) {
      if (!url) throw new Error('service_not_configured');
      let parsed;
      try { parsed = new URL(url); } catch { throw new Error('invalid_service_url'); }
      if (parsed.username || parsed.password || parsed.hash || parsed.search || parsed.pathname !== '/ws' || !['wss:', 'ws:'].includes(parsed.protocol)) throw new Error('invalid_service_url');
      if (parsed.protocol === 'ws:' && (location.protocol === 'https:' || !['localhost', '127.0.0.1', '[::1]'].includes(parsed.hostname))) throw new Error('secure_service_required');
    }
    open(auth) {
      if (this.active) throw new Error('already_in_room');
      this.validateUrl(this.config.signalingUrl);
      this.openedAt = Date.now(); this.active = true; this.auth = auth;
      this.retry = 0; this.disconnectedAt = 0; this.lastPacket = Date.now();
      this.connectSocket(); this.changed();
    }
    connectSocket() {
      if (!this.active) return;
      const ws = new WebSocket(this.config.signalingUrl); this.ws = ws;
      this.socketOpenedAt = Date.now(); this.lastPacket = Date.now();
      ws.onopen = () => {
        if (this.ws !== ws || !this.active) return;
        this.state.connectionStage = this.auth.op === 'create' ? 'creating_room' : this.auth.op === 'join' ? 'joining_room' : 'restoring_seat';
        this.changed(); ws.send(JSON.stringify({ ...this.auth, build: this.config.build }));
      };
      ws.onmessage = (event) => {
        if (this.ws !== ws || !this.active) return;
        this.lastPacket = Date.now();
        try { this.message(JSON.parse(event.data)); } catch { this.error('invalid_server_message'); }
      };
      ws.onerror = () => { this.state.status = 'reconnecting'; this.changed(); };
      ws.onclose = (event) => {
        if (this.ws !== ws || !this.active) return;
        if (event.reason === 'replaced') { this.finish('session_replaced'); return; }
        this.state.status = 'reconnecting'; this.state.connectionStage = 'reconnecting';
        this.disconnectedAt ||= Date.now(); this.changed();
        if (!this.auth.token) { this.finish('connection_failed'); return; }
        this.retryAt = Date.now() + Math.min(4000, 500 * 2 ** this.retry++) + Math.random() * 250;
      };
    }
    send(data) {
      if (this.ws?.readyState !== WebSocket.OPEN || this.ws.bufferedAmount > 128000) throw new Error('reconnecting');
      this.ws.send(JSON.stringify(data));
    }
    message(msg) {
      switch (msg.type) {
        case 'welcome': {
          if (msg.room?.topology !== 'dedicated' || msg.room.build !== this.config.build) { this.finish('incompatible_build'); return; }
          this.state.id = msg.id; this.retry = 0; this.disconnectedAt = 0; this.retryAt = 0;
          this.timeouts = msg.timeouts; this.state.error = '';
          this.auth = { op: 'resume', room: msg.room.id, id: msg.id, token: msg.token };
          this.storage('sessionStorage', this.preferenceKey + ':resume', JSON.stringify({ ...this.auth, endpoint: this.config.signalingUrl }));
          if (msg.invite) {
            const url = new URL(location.href); url.search = '';
            url.hash = new URLSearchParams({ room: msg.room.id, invite: msg.invite }).toString();
            this.state.invitation = url.href;
            // Preserve the creator's invitation across reload without storing it server-side.
            this.storage('sessionStorage', this.key() + ':invite', url.href);
          } else this.state.invitation = this.storage('sessionStorage', this.key() + ':invite') || this.state.invitation;
          this.updateRoom(msg.room); break;
        }
        case 'room': this.updateRoom(msg.room); break;
        case 'snapshot': {
          const s = msg.snapshot;
          if (!s || !Number.isSafeInteger(s.revision) || !Number.isSafeInteger(msg.round) || !Array.isArray(s.players) || s.players.length !== 2 ||
            !s.players.some((p) => p.id === this.state.id && Array.isArray(p.hand)) || s.players.some((p) => p.id !== this.state.id && ('hand' in p || 'deck' in p))) throw new Error('invalid_snapshot');
          if (msg.round < (this.state.round || 0) || (msg.round === this.state.round && s.revision < (this.state.snapshot?.revision || 0))) return;
          this.state.round = msg.round; this.state.snapshot = s; this.state.screen = 'match';
          this.state.serverOffsetMs = msg.serverTime - Date.now();
          break;
        }
        case 'pong': this.state.rttMs = Date.now() - msg.t; break;
        case 'ended': this.finish(msg.reason); break;
        case 'error':
          if (!this.auth?.token) {
            this.active = false; this.ws?.close(); this.state.screen = 'setup'; this.state.status = 'setup'; this.error(msg.code); break;
          }
          if (['room_unavailable', 'resume_denied', 'resume_expired', 'session_expired', 'incompatible_build'].includes(msg.code)) this.finish(msg.code);
          else this.error(msg.code);
          break;
      }
      this.changed();
    }
    updateRoom(room) {
      this.state.room = room;
      const self = room.members.find((m) => m.id === this.state.id);
      this.state.ready = !!self?.ready; this.state.rematch = !!self?.rematch;
      this.state.canRematch = room.phase === 'ended' && room.members.length === 2 && room.members.every((m) => m.connected);
      this.state.canStart = room.leader === this.state.id && room.phase === 'lobby' && room.members.length === 2 && room.members.every((m) => m.connected && m.ready);
      this.state.status = this.ws?.readyState !== WebSocket.OPEN ? 'reconnecting' : room.members.some((m) => !m.connected) ? 'opponent_reconnecting' : 'connected';
      this.state.connectionStage = room.phase === 'lobby' && room.members.length === 1 ? 'waiting_players' : this.state.status;
      this.state.screen = room.phase === 'lobby' ? 'lobby' : 'match'; this.changed();
    }
    action(action) {
      if (!this.state.snapshot || this.state.status !== 'connected') throw new Error('reconnecting');
      this.send({ op: 'action', round: this.state.round, action: { ...action, id: crypto.randomUUID(), revision: this.state.snapshot.revision } });
    }
    tick() {
      if (!this.active) return;
      const now = Date.now();
      if (!this.auth?.token && now - this.openedAt > 15000) { this.finish('connection_failed'); return; }
      if (this.disconnectedAt && now - this.disconnectedAt > (this.timeouts?.guestGraceMs || 90000) + 20000) { this.finish('connection_lost'); return; }
      if (this.retryAt && now >= this.retryAt) { this.retryAt = 0; this.connectSocket(); }
      if (this.ws?.readyState === WebSocket.CONNECTING && now - this.socketOpenedAt > 10000) this.ws.close();
      if (this.ws?.readyState === WebSocket.OPEN) {
        if (now - this.lastPacket > 20000) { this.ws.close(); return; }
        if (now - (this.lastPing || 0) > 5000) { this.lastPing = now; try { this.send({ op: 'ping', t: now }); } catch { this.ws.close(); } }
      }
    }
    finish(reason) {
      this.active = false; this.ws?.close(); this.auth = null;
      this.clearSaved();
      this.state.screen = 'ended'; this.state.status = reason; this.state.error = ''; this.changed();
    }
    clearInvitation() {
      if (new URLSearchParams(location.hash.slice(1)).has('room')) {
        const url = new URL(location.href); url.hash = ''; window.history?.replaceState(null, '', url.href);
      }
    }
    leave() {
      this.autoEntryCancelled = true; this.attempt = (this.attempt || 0) + 1; this.pending = false;
      if (this.active && this.ws?.readyState === WebSocket.OPEN) { try { this.send({ op: 'leave' }); } catch {} }
      this.active = false; this.ws?.close(); this.auth = null;
      if (this.config) this.clearSaved();
    }
    dispose() { this.disposed = true; this.discoveryController?.abort(); this.leave(); clearInterval(this.timer); window.removeEventListener('pagehide', this.unload); window.removeEventListener('pageshow', this.restore); }
  }
  window.EmberpanMP?.dispose();
  window.EmberpanMP = new Client();
})();
