// Native UI metadata is generated from the same definitions used by the server.
import { writeFileSync } from 'node:fs';
import '../multiplayer/rules.js';

writeFileSync(new URL('../multiplayer/cards.json', import.meta.url),
  JSON.stringify(globalThis.EmberpanRules.CARDS, null, 2) + '\n');
