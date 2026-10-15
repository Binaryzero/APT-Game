#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";

const inputPath = process.argv[2] || "test-run.log";
const outputPath = process.argv[3] || "coverage/latest.json";
const log = fs.readFileSync(inputPath, "utf8");

function jsonLine(prefix, required = true) {
  const escaped = prefix.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const match = log.match(new RegExp(`^${escaped} (\\{[^\\r\\n]*\\})$`, "m"));
  if (!match) {
    if (required) throw new Error(`Missing ${prefix} output in ${inputPath}`);
    return null;
  }
  return JSON.parse(match[1]);
}

function scalarLine(prefix, pattern) {
  const match = log.match(new RegExp(`^${prefix} ${pattern}$`, "m"));
  if (!match) throw new Error(`Missing ${prefix} output in ${inputPath}`);
  return match;
}

const smoke = scalarLine("PT_SMOKE_TEST_OK", "cards=(\\d+) mapped_art=(\\d+) player_counts=([0-9,]+)");
const engine = jsonLine("PT_SUMMARY");
const cardCoverage = jsonLine("PT_CARD_COVERAGE");
const deckMatch = scalarLine("PT_DECK", "(\\{[^\\r\\n]*\\}) total (\\d+)");
const deckCounts = JSON.parse(deckMatch[1]);
const deckSize = Number(deckMatch[2]);
const neverPlayedMatch = log.match(/^PT_NEVER_PLAYED (\[[^\r\n]*\])$/m);
if (!neverPlayedMatch) throw new Error(`Missing PT_NEVER_PLAYED output in ${inputPath}`);
const neverPlayed = JSON.parse(neverPlayedMatch[1]);
if (!log.includes("PT_ENGINE_TEST_OK") || log.includes("PT_ENGINE_TEST_FAILED") || log.includes("PT_SMOKE_TEST_FAILED")) {
  throw new Error("The test log does not contain a clean passing result from both suites.");
}
if (neverPlayed.length || (Array.isArray(cardCoverage.missing) && cardCoverage.missing.length)) {
  throw new Error("One or more playable card definitions were not exercised by deterministic simulations.");
}

const deckOutOutcomes = {
  count: Number(engine.count || 0),
  malware: Number(engine.malware || 0),
  software: Number(engine.software || 0),
  rps: Number(engine.rps || 0)
};
const deckOutScenarios = Object.values(deckOutOutcomes).reduce((sum, count) => sum + count, 0);
const cardsAvailable = Number(cardCoverage.available);
const cardsTested = Number(cardCoverage.tested);
const cardPercent = cardsAvailable > 0 ? Math.round((cardsTested / cardsAvailable) * 100) : 0;
const artMapped = Number(smoke[2]);
const playableDefinitions = Number(cardCoverage.available);
const artPercent = playableDefinitions > 0 ? Math.round((artMapped / playableDefinitions) * 100) : 0;
const testedCommit = process.env.GITHUB_SHA || "local";
const repo = process.env.GITHUB_REPOSITORY || "Binaryzero/APT-Game";
const runId = process.env.GITHUB_RUN_ID || "";

const report = {
  schemaVersion: 1,
  kind: "behavioral-test-coverage",
  metadata: {
    repository: repo,
    generatedAt: new Date().toISOString(),
    testedCommit,
    branch: process.env.GITHUB_REF_NAME || "local",
    workflowRun: runId ? `https://github.com/${repo}/actions/runs/${runId}` : null
  },
  coverage: {
    model: "behavioral exercise; not source-line coverage",
    cardBehavior: {
      tested: cardsTested,
      available: cardsAvailable,
      percent: cardPercent,
      notExercised: neverPlayed
    },
    playableCardArtwork: {
      mapped: artMapped,
      playableCards: playableDefinitions,
      percent: artPercent,
      totalDefinitions: Number(smoke[1])
    },
    playerCounts: smoke[3].split(",").map(Number),
    sourceLineCoverage: {
      instrumented: false,
      note: "GDScript line coverage is not currently instrumented."
    }
  },
  tests: {
    smokeSuite: "passed",
    engineSimulationSuite: "passed",
    completeMatches: Number(engine.games),
    totalTurns: Number(engine.turns),
    deckOutScenarios,
    deckOutOutcomes,
    deckSize,
    deckComposition: deckCounts
  }
};

fs.mkdirSync(path.dirname(outputPath), { recursive: true });
fs.writeFileSync(outputPath, `${JSON.stringify(report, null, 2)}\n`);

const summary = [
  "## APT-Game behavioral test coverage",
  "",
  `- Playable card definitions exercised: **${cardsTested}/${cardsAvailable} (${cardPercent}%)**`,
  `- Playable card-art mappings checked: **${artMapped}/${playableDefinitions} (${artPercent}%)**`,
  `- Deterministic complete matches: **${engine.games}** across **${engine.turns}** turns`,
  `- Forced deck-exhaustion scenarios: **${deckOutScenarios}** (${deckOutOutcomes.count} count, ${deckOutOutcomes.malware} malware, ${deckOutOutcomes.software} software, ${deckOutOutcomes.rps} RPS)`,
  `- Player counts covered: **${smoke[3].replaceAll(",", ", ")}**`,
  "- Source-line coverage: **not instrumented**; metrics above are behavioral coverage."
].join("\n");
if (process.env.GITHUB_STEP_SUMMARY) fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, `${summary}\n`);
console.log(`COVERAGE_REPORT_WRITTEN ${outputPath} cards=${cardsTested}/${cardsAvailable} matches=${engine.games} deckout=${deckOutScenarios}`);
