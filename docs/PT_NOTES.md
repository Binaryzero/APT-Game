# Packet Tactics - working notes (project: /home/ubuntu/packetact, Godot 4.7 web game, trading-card starter)

## Source: /home/ubuntu/upload/APTGAME_RULE_BOOK.pdf (Advanced Persistent Threat, Spectant Security) - key rules
- 138 game cards, 14 adversary cards (cosmetic identity), 8 reference cards.
- Setup: each player picks ADVERSARY; gets 1 STAGING SERVER (placed face up in NETWORK) + 1 SMALL DDOS (0DAY) in hand; shuffle rest, deal 5 each; DECK + DISCARD pile.
- Terms: NETWORK (play area), DELETE (any network -> discard), UNINSTALL (own network -> discard), STEAL (any network -> your network), DISCARD (hand -> discard).
- Card types: Production Server (db icon, enter/leave effects), Staging Server (no effects), Software (floppy, positive), Malware (biohazard, negative, installable in ANY network incl own), Exploit (bomb, single use -> discard), 0DAY (skull, playable ANY time even during another player's card; unlimited, back-to-back).
- Turn: 1 beginning-of-turn effects (simultaneous) 2 DRAW 3 EITHER play Server/Software/Malware/Exploit (read aloud) OR draw a card 4 DISCARD to hand limit 7 (modified by network cards).
- Win: first to 6 SERVERS (5 short, 7 long). Deck out: most servers wins; tie -> least malware in network; tie -> most software; tie -> best 2 of 3 Rock Paper Scissors.
- Software/Malware only on SERVERS already in a network; 1 software per server; 1 malware per server; malware goes ON TOP of software (cancels its effect); software can NOT go on malware. Effects apply to entire network. Server uninstalled/deleted -> its software+malware also discarded. "Return this card to hand" returns only server; attachments go to discard. Cards returning ANY card to hand can't reach software under malware.
- Cloud Storage example: hand limit +3. Network Worm example: move Software/Malware from any network to any other player's network. Small DDoS 0DAY cancels a played card; can be countered by another DDoS (chain). TLS Decryption malware: hand must be visible to all (=> hands are normally PRIVATE).
- Clarifications: SERVER/SOFTWARE/MALWARE have no effect in hand; only active in network. Stolen: leave-effect fires for victim then enter-effect for thief. Optional ("may") effects can't be retroactively used after drawing step; mandatory must be done when noticed. Beginning effects simultaneous. 0DAY modifies what a player does when PLAYING a card; can't cancel already-played server/software/malware effects. Any player=incl you; another=excl you; each=all. Multi-action effects: if first part impossible, second not performed. Exploits & malware CAN be played on/against yourself. Remote Root can block/reflect MULTIPLE deletions from a single card. Process Kill prevents SERVER "Entering Network" effects too.

## Decisions made
- Original identity "Packet Tactics"; original card names/text (not official). Rulebook text/logo/art not copied. English only.
- 133-card deck in scripts/pt/pt_defs.gd (+4 starter staging per player pulled out separately) + 6 adversary callsigns cosmetic.
- Engine: scripts/pt/pt_engine.gd (async, brains), pt_ai.gd (deterministic AI), pt_card.gd, pt_defs.gd. Test: test/pt_engine_test.gd (headless: `godot --headless --path . --script res://test/pt_engine_test.gd`) - PASSED 122 games.
- Art generated: assets/pt/art_{production,staging,software,malware,exploit,zeroday}.webp, bg_circuit.webp (768x512 / 1280x720)
- Colors: prod #27d3f5, stage #6f93ff, soft #3dff8e, mal #ff5a3c, exploit #ffb21f, zd #c77dff.
- GODOT: /usr/local/bin/godot ; GAME_RUNTIME=/home/ubuntu/.manus-addons/manus-webdev-sha-48128aa19f3fef08/runtime/game-dev ; preview: GAME_RUNTIME=... HOST=0.0.0.0 PORT=3000 npm run dev (service); preview build: node "$GAME_RUNTIME/preview-build.mjs"
- Delivery: npm run check ; node "$GAME_RUNTIME/save-release.mjs" --message "..." ; npm run check -- --pack ; push exact SHA to origin main. Game publishing config must be build.command=true outputDirectory=site (GET webdev.config config).
- TODO remaining: UI (scenes/packet_game.tscn + scripts/pt/pt_ui*.gd), human brain, boot.gd retarget + reskin, loading.html reskin, project.godot name/main scene, runtime tweak catalog replace, remove/neutralize old card_game tests, hot-seat curtain, rules reference modal, RPS UI, favicon/sharing, checkpoint.
