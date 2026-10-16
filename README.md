# Packet Tactics

**Build your network. Install. Exploit. Answer with a 0DAY.**

Packet Tactics is an original, turn-based cybersecurity card game built with Godot 4. Play on one device against one to three deterministic AI opponents, or pass the device between two to four people in Hot Seat mode. The game includes a 133-card representative deck, original card names and text, and custom cyber-themed illustrations.

This is an unofficial, original adaptation inspired by gameplay concepts in the supplied *Advanced Persistent Threat* rulebook. It is not an official edition or affiliated product. Packet Tactics uses its own identity, card text, interface, and artwork.

## Play a match

At the title screen, choose **VS AI Opponents** or **Hot Seat (Same Device)**. Select two to four total players and a server goal of five, six, or seven. Six is the standard goal. Enter a handle and choose **Start Game**. The **How to Play / Card Codex** button explains the rules and lists the cards; the **Rules** button stays available during a match.

In AI mode, you control one seat and the AI plays the others. In Hot Seat mode, the game pauses between players and shows a privacy curtain so the next player can take over without seeing the previous player’s hand. The event log records actions as they resolve. Hover over a card to inspect its rules text and artwork.

## Gameplay rules

### Goal and setup

Be the first player to control the selected number of servers in your Network. Each player begins with one **Staging Server**, one **Small DDoS** 0DAY, and five additional cards. Hands are private unless an effect such as Traffic Sniffer reveals them. The normal hand limit is seven cards.

A Network is a row of Servers. Each Server can carry one Software attachment and one Malware attachment. Attachments only have effects while installed in a Network; they do nothing in a hand. The card text describes when each effect applies.

### Turn sequence

1. **Begin:** Resolve beginning-of-turn effects in your Network. Mandatory effects happen; effects marked “MAY” are optional.
2. **Draw:** Draw one card unless an effect changes the amount.
3. **Act:** Play one eligible Server, Software, Malware, or Exploit from your hand—or draw one extra card instead. Some effects grant additional plays. Follow the prompts to choose targets or options.
4. **Discard:** If you are over your current hand limit, discard down to it. Network effects can raise or lower that limit.

Click a card in your hand to select it, then press **Play**. Choose from the highlighted targets when asked. A 0DAY response may be played at any time, including while another player is playing a card. Responses can be chained; the stack resolves newest-first. Speed controls change animation pace, not the rules.

### Card types and interactions

- **Production Servers** have entry, exit, or beginning-of-turn effects. **Staging Servers** have no special effect.
- **Software** helps its network owner and can only be installed on a Server in your own Network. You cannot install Software on a Server that already has Malware.
- **Malware** can be installed on any Server, including your own. It sits above Software and suppresses that Software while present.
- **Exploits** resolve once and are discarded. Depending on the card, they can delete, steal, uninstall, discard, move, or otherwise disrupt cards.
- **0DAYs** are instant responses. **Small DDoS** cancels a card being played. **Process Kill** prevents an eligible card from entering a Network and draws a card. **Remote Root** blocks or reflects certain Exploits. **Backdoor Cache** draws two cards on your turn without using your play.

When a Server leaves a Network, its Software and Malware are discarded. If a Server is stolen, its old owner’s leave effect resolves before its new owner’s entry effect. A 0DAY can change how a card being played resolves; it cannot undo an effect that has already happened on the board. Consult the in-game Rules and Codex for card-specific targets and exceptions.

### Winning and deck exhaustion

The first player to reach the selected server goal wins immediately. If the deck runs out first, Networks are compared in this order:

1. Most Servers.
2. Fewest Malware cards in the Network.
3. Most Software cards in the Network.
4. If still tied, a best-of-three Rock–Paper–Scissors tiebreaker.

## Installation and running locally

### Requirements

- [Godot Engine 4.7.2](https://godotengine.org/download/), standard non-.NET edition.
- Git, if you are cloning the repository.
- Node.js 20 or newer is optional. It is used by convenience scripts and the GitHub workflow, not by the Godot game itself.

The repository includes the game source, fonts, and runtime artwork. Local play does not require a game account, backend, API key, or paid dependency.

### Run in the Godot editor

1. Clone the repository:

   ```sh
   git clone https://github.com/Binaryzero/APT-Game.git
   cd APT-Game
   ```

2. Open the folder containing `project.godot` in Godot’s Project Manager and let Godot import the resources.
3. Press **F5** to run the configured boot scene and open the title screen. **F6** runs the currently selected scene in the editor.

You can also launch the configured project from a terminal after putting Godot on your `PATH`:

```sh
godot --path .
```

### Run automated tests

No npm packages need to be installed. After installing Godot and letting it import the project, run:

```sh
npm test
```

This imports the project, checks starting state for two-, three-, and four-player matches, verifies that card definitions resolve to valid illustrations, confirms targeted cards go straight from hand selection to board targeting, and runs 122 complete deterministic AI matches plus 48 forced deck-exhaustion scenarios. The simulation checks card conservation, unique card IDs, server and attachment placement, deterministic replays, card coverage, and deck-exhaustion outcomes.

Run either test layer on its own with:

```sh
npm run test:smoke
npm run test:ui
npm run test:engine
```

### Export and run the Web build

Install the **Web export templates** for Godot 4.7.2 in Godot’s Export Templates manager, then use the included **Web** preset:

```sh
npm run export:web
```

The browser build is written to `dist/`. Serve that directory over HTTP instead of opening `index.html` directly. For a quick local server, run:

```sh
python3 -m http.server 8000 --directory dist
```

Then open <http://localhost:8000>. Keep every generated file in `dist/` together when hosting the game.

## Continuous integration and releases

The workflow in [`.github/workflows/game-ci.yml`](.github/workflows/game-ci.yml) runs on pull requests to `main`, pushes to `main`, version-tag pushes, and manual dispatch. It installs Godot 4.7.2 and the Web export templates, imports the project, runs `npm test`, exports the Web build, and uploads a downloadable build artifact that is retained for 14 days. After a successful `main` run, it also writes a behavioral-coverage snapshot to [`coverage/latest.json`](coverage/latest.json).

Push a version tag such as `v0.1.0` to run the same checks and export, then create a GitHub Release with `PacketTactics-Web.zip` attached if they pass:

```sh
git tag v0.1.0
git push origin v0.1.0
```

A version tag is the release switch for downloadable game releases. Every successful push to `main` also deploys the dashboard to GitHub Pages after the game tests and Web export pass.

## Live status dashboard

The read-only dashboard is in [`dashboard/`](dashboard/) and is permanently hosted at <https://binaryzero.github.io/APT-Game/>. Every successful push to `main` publishes the dashboard automatically; its live CI and coverage panels read the public GitHub Actions API and latest passing coverage snapshot. It requires no login or GitHub token.

To run it locally from the repository root instead, use:

```sh
python3 -m http.server 8000
```

Open <http://localhost:8000/dashboard/>. It polls the public GitHub Actions API once per minute and loads the latest passing test snapshot from the repository. The coverage panel reports deterministic behavioral exercise (cards, setup counts, and deck-exhaustion outcomes); **GDScript source-line coverage is not instrumented**.

## Project layout

- `scenes/` — Godot scenes and the game entry point.
- `scripts/pt/` — card definitions, rules engine, deterministic AI, human input, interface, and rules reference.
- `assets/pt/cards/` — card illustrations; `assets/pt/` also contains the board background and card-type art.
- `assets/template/fonts/` — UI fonts and the license notices required for redistribution. Unrelated starter-game media is excluded.
- `test/pt_smoke_test.gd` — fast checks for artwork mappings and initial state.
- `test/pt_engine_test.gd` — deterministic AI match simulations.
- `tools/generate_coverage_report.mjs` — converts passing test output into the coverage snapshot.
- `dashboard/` — live, read-only CI/CD and behavioral-coverage status page.
- `coverage/latest.json` — latest passing `main` coverage snapshot, refreshed by CI.
- `.github/workflows/game-ci.yml` — automated tests, Web export, and tag-based releases.

## License and notices

See [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) for notices covering included third-party resources. The Packet Tactics rules implementation, card text, and generated illustrations are included in this repository. Retain applicable notices when redistributing third-party fonts or template resources.
