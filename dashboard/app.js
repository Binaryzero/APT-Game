const OWNER = "Binaryzero";
const REPO = "APT-Game";
const API_ROOT = `https://api.github.com/repos/${OWNER}/${REPO}`;
const COVERAGE_URL = `https://raw.githubusercontent.com/${OWNER}/${REPO}/main/coverage/latest.json`;
const POLL_MS = 60_000;

const $ = (id) => document.getElementById(id);
const state = { runs: [], lastRunsFetch: 0, lastCoverageFetch: 0, coverageSha: "", busy: false };
const nf = new Intl.NumberFormat("en-US");

function safeDate(value) {
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
}

function relativeTime(value) {
  const date = safeDate(value);
  if (!date) return "—";
  const seconds = Math.round((date.getTime() - Date.now()) / 1000);
  const abs = Math.abs(seconds);
  if (abs < 45) return "just now";
  const units = [[60, "minute"], [3600, "hour"], [86400, "day"], [604800, "week"]];
  let amount = seconds;
  let unit = "second";
  for (const [threshold, name] of units) {
    if (abs >= threshold) {
      amount = Math.round(seconds / threshold);
      unit = name;
    } else break;
  }
  return `${Math.abs(amount)} ${unit}${Math.abs(amount) === 1 ? "" : "s"} ${amount < 0 ? "ago" : "from now"}`;
}

function exactTime(value) {
  const date = safeDate(value);
  return date ? date.toLocaleString(undefined, { dateStyle: "medium", timeStyle: "short" }) : "—";
}

function duration(run) {
  const start = safeDate(run.run_started_at || run.created_at);
  const end = safeDate(run.updated_at) || new Date();
  if (!start) return "—";
  const seconds = Math.max(0, Math.round((end - start) / 1000));
  if (seconds < 60) return `${seconds}s`;
  const minutes = Math.floor(seconds / 60);
  const rest = seconds % 60;
  if (minutes < 60) return `${minutes}m ${rest}s`;
  return `${Math.floor(minutes / 60)}h ${minutes % 60}m`;
}

function statusFor(run) {
  if (run.status === "queued" || run.status === "waiting" || run.status === "requested") return { label: "Queued", tone: "neutral", detail: "Waiting for a runner" };
  if (run.status === "in_progress") return { label: "Running", tone: "progress", detail: "Checks are in progress" };
  const conclusion = String(run.conclusion || "unknown").toLowerCase();
  if (conclusion === "success") return { label: "Success", tone: "success", detail: "All required steps passed" };
  if (["failure", "timed_out", "startup_failure", "action_required"].includes(conclusion)) return { label: "Failed", tone: "failure", detail: conclusion.replaceAll("_", " ") };
  if (["cancelled", "skipped", "neutral"].includes(conclusion)) return { label: conclusion[0].toUpperCase() + conclusion.slice(1), tone: "neutral", detail: `Run ${conclusion}` };
  return { label: "Unknown", tone: "neutral", detail: "GitHub has not reported a conclusion" };
}

function makeNode(tag, className, text) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text !== undefined) node.textContent = text;
  return node;
}

function clear(node) {
  while (node.firstChild) node.removeChild(node.firstChild);
}

function validGitHubUrl(value) {
  try {
    const url = new URL(value);
    return url.protocol === "https:" && url.hostname === "github.com" ? url.href : `https://github.com/${OWNER}/${REPO}/actions`;
  } catch {
    return `https://github.com/${OWNER}/${REPO}/actions`;
  }
}

function renderRunRow(run) {
  const row = document.createElement("tr");
  const status = statusFor(run);
  const resultCell = makeNode("td");
  resultCell.append(makeNode("span", `run-status status-${status.tone}`, status.label));

  const runCell = makeNode("td");
  const title = String(run.display_title || run.name || "Workflow run");
  runCell.append(makeNode("span", "run-title", title));
  runCell.append(makeNode("span", "run-commit", `${String(run.head_sha || "").slice(0, 7) || "unknown"} · ${String(run.event || "event").replaceAll("_", " ")}`));

  const branchCell = makeNode("td");
  branchCell.append(makeNode("span", "branch-label", run.head_branch || "tag / detached"));

  const timeCell = makeNode("td");
  const time = makeNode("span", "time-cell", relativeTime(run.created_at));
  time.title = exactTime(run.created_at);
  timeCell.append(time);

  const durationCell = makeNode("td", "duration-cell", duration(run));
  durationCell.title = run.run_started_at ? `Started ${exactTime(run.run_started_at)}` : "Run duration";

  const linkCell = makeNode("td");
  const link = makeNode("a", "open-run", "↗");
  link.href = validGitHubUrl(run.html_url);
  link.target = "_blank";
  link.rel = "noopener noreferrer";
  link.setAttribute("aria-label", `Open workflow run ${title}`);
  linkCell.append(link);

  row.append(resultCell, runCell, branchCell, timeCell, durationCell, linkCell);
  return row;
}

function updateConnection(message, tone = "ok") {
  const root = $("connection-state");
  root.replaceChildren();
  const dot = makeNode("i", "pulse-dot");
  dot.setAttribute("aria-hidden", "true");
  if (tone === "error") dot.style.background = "var(--red)";
  else if (tone === "loading") dot.style.background = "var(--amber)";
  root.append(dot, makeNode("span", "", message));
}

function renderLatest(run) {
  const card = $("health-card");
  card.classList.remove("tone-success", "tone-failure", "tone-progress");
  $("health-job").hidden = true;
  if (!run) {
    $("health-status").textContent = "No runs found";
    $("health-detail").textContent = "No matching workflow run is available yet.";
    $("health-branch").textContent = "Branch —";
    $("health-sha").textContent = "Commit —";
    return;
  }
  const status = statusFor(run);
  if (status.tone === "success") card.classList.add("tone-success");
  if (status.tone === "failure") card.classList.add("tone-failure");
  if (status.tone === "progress") card.classList.add("tone-progress");
  $("health-status").textContent = status.label;
  $("health-detail").textContent = `${status.detail} · ${relativeTime(run.created_at)}`;
  $("health-branch").textContent = `Branch ${run.head_branch || "tag / detached"}`;
  $("health-sha").textContent = `Commit ${String(run.head_sha || "").slice(0, 7) || "—"}`;
}

function renderRuns(runs) {
  const body = $("run-rows");
  clear(body);
  if (!runs.length) {
    const row = document.createElement("tr");
    const cell = makeNode("td", "empty-cell", "No Game CI runs found.");
    cell.colSpan = 6;
    row.append(cell);
    body.append(row);
    $("runs-count").textContent = "0 matching runs";
    renderLatest(null);
    return;
  }
  for (const run of runs.slice(0, 10)) body.append(renderRunRow(run));
  $("runs-count").textContent = `${runs.length} recent run${runs.length === 1 ? "" : "s"} loaded`;
  renderLatest(runs[0]);

  const latest = runs[0];
  if (latest.status !== "completed") {
    $("health-job").hidden = false;
    $("health-job").textContent = latest.status === "queued" ? "Runner allocation pending" : "Live run · check the run page for current step detail";
  }
}

function percent(tested, total) {
  if (!Number.isFinite(tested) || !Number.isFinite(total) || total <= 0) return 0;
  return Math.max(0, Math.min(100, Math.round((tested / total) * 100)));
}

function setBar(id, value) {
  $(id).style.width = `${Math.max(0, Math.min(100, Number(value) || 0))}%`;
}

function renderCoverage(report, cached = false) {
  const coverage = report?.coverage || {};
  const cards = coverage.cardBehavior || {};
  const art = coverage.playableCardArtwork || {};
  const tests = report?.tests || {};
  const outcomes = tests.deckOutOutcomes || {};
  const cardPercent = percent(Number(cards.tested), Number(cards.available));
  const artPercent = percent(Number(art.mapped), Number(art.playableCards));

  $("cards-tested").textContent = Number.isFinite(Number(cards.tested)) ? nf.format(cards.tested) : "—";
  $("cards-total").textContent = `/ ${Number.isFinite(Number(cards.available)) ? nf.format(cards.available) : "—"}`;
  $("card-progress").style.width = `${cardPercent}%`;
  $("card-progress-bar").setAttribute("aria-valuenow", String(cardPercent));
  $("card-coverage-percent").textContent = Number.isFinite(Number(cards.available)) ? `${cardPercent}% exercised` : "Awaiting coverage report";
  $("match-count").textContent = Number.isFinite(Number(tests.completeMatches)) ? nf.format(tests.completeMatches) : "—";
  $("turn-count").textContent = Number.isFinite(Number(tests.totalTurns)) ? `${nf.format(tests.totalTurns)} turns` : "— turns";
  $("deckout-count").textContent = Number.isFinite(Number(tests.deckOutScenarios)) ? nf.format(tests.deckOutScenarios) : "—";
  const outcomeTotal = Object.values(outcomes).reduce((sum, value) => sum + (Number(value) || 0), 0);
  $("deckout-outcomes").textContent = outcomeTotal ? `${Object.keys(outcomes).length} tie-break paths` : "Awaiting report";
  const players = Array.isArray(coverage.playerCounts) ? coverage.playerCounts : [];
  $("player-counts").textContent = players.length ? `${Math.min(...players)}–${Math.max(...players)}` : "—";
  $("art-count").textContent = Number.isFinite(Number(art.mapped)) ? `${nf.format(art.mapped)} art mappings` : "— art mappings";
  $("card-coverage-value").textContent = Number.isFinite(Number(cards.available)) ? `${nf.format(cards.tested)} / ${nf.format(cards.available)} · ${cardPercent}%` : "—";
  $("art-coverage-value").textContent = Number.isFinite(Number(art.playableCards)) ? `${nf.format(art.mapped)} / ${nf.format(art.playableCards)} · ${artPercent}%` : "—";
  setBar("card-coverage-track", cardPercent);
  setBar("art-coverage-track", artPercent);
  $("winner-paths").textContent = outcomeTotal ? String(Object.keys(outcomes).length) : "—";
  $("deck-size").textContent = Number.isFinite(Number(tests.deckSize)) ? nf.format(tests.deckSize) : "—";

  const outcomeList = $("outcome-list");
  clear(outcomeList);
  const labels = { count: "Server-count tie-break", malware: "Malware tie-break", software: "Software tie-break", rps: "RPS duel" };
  const keys = Object.keys(labels);
  if (!outcomeTotal) outcomeList.append(makeNode("span", "muted", "No deck-out metrics available."));
  for (const key of keys) {
    const item = makeNode("span", "outcome-item");
    item.append(makeNode("span", "", labels[key]), makeNode("strong", "", Number.isFinite(Number(outcomes[key])) ? nf.format(outcomes[key]) : "0"));
    outcomeList.append(item);
  }

  const sha = String(report?.metadata?.testedCommit || "").slice(0, 7);
  const generatedAt = report?.metadata?.generatedAt ? exactTime(report.metadata.generatedAt) : "unknown time";
  const isCiSnapshot = Boolean(report?.metadata?.workflowRun);
  $("coverage-source").textContent = `${isCiSnapshot ? "Passing CI snapshot" : "Local test snapshot"} · ${generatedAt}${sha ? ` · tested ${sha}` : ""}${cached ? " · cached" : ""}`;
  $("coverage-state").textContent = cached ? "CACHED REPORT" : isCiSnapshot ? "PASSING CI SNAPSHOT" : "LOCAL TEST SNAPSHOT";
  $("coverage-state").style.color = cached ? "var(--amber)" : "var(--cyan)";
}

function showError(message) {
  const banner = $("error-banner");
  banner.textContent = message;
  banner.hidden = false;
}

function clearError() {
  $("error-banner").hidden = true;
  $("error-banner").textContent = "";
}

async function fetchRuns() {
  const response = await fetch(`${API_ROOT}/actions/runs?per_page=30`, {
    headers: { Accept: "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28" },
    cache: "no-store"
  });
  const remaining = response.headers.get("x-ratelimit-remaining");
  const limit = response.headers.get("x-ratelimit-limit");
  if (!response.ok) {
    const error = new Error(`GitHub API returned ${response.status}${response.status === 403 ? " (rate limit or access restriction)" : ""}.`);
    error.rate = remaining && limit ? `${remaining}/${limit} API requests remain` : "";
    throw error;
  }
  const payload = await response.json();
  const workflows = Array.isArray(payload.workflow_runs) ? payload.workflow_runs : [];
  const filtered = workflows.filter((run) => run.name === "Game CI and releases" || String(run.path || "").includes("game-ci.yml"));
  filtered.sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
  state.runs = filtered;
  state.lastRunsFetch = Date.now();
  localStorage.setItem("apt-game-runs", JSON.stringify({ savedAt: state.lastRunsFetch, runs: filtered }));
  updateConnection(`GitHub API · ${remaining && limit ? `${remaining}/${limit} left` : "connected"}`, "ok");
  return filtered;
}

async function fetchCoverage() {
  const remote = new URL(COVERAGE_URL);
  remote.searchParams.set("v", String(Date.now()));
  const local = new URL("../coverage/latest.json", window.location.href);
  let report = null;
  let lastError = null;
  for (const url of [remote, local]) {
    try {
      const response = await fetch(url, { cache: "no-store" });
      if (!response.ok) throw new Error(`Coverage report returned ${response.status}.`);
      report = await response.json();
      break;
    } catch (error) {
      lastError = error;
    }
  }
  if (!report) throw lastError || new Error("Coverage report is unavailable.");
  state.lastCoverageFetch = Date.now();
  state.coverageSha = String(report?.metadata?.testedCommit || "");
  localStorage.setItem("apt-game-coverage", JSON.stringify({ savedAt: state.lastCoverageFetch, report }));
  renderCoverage(report);
  return report;
}

function restoreCached() {
  try {
    const cachedRuns = JSON.parse(localStorage.getItem("apt-game-runs") || "null");
    if (cachedRuns?.runs) renderRuns(cachedRuns.runs);
  } catch { /* Ignore malformed local cache. */ }
  try {
    const cachedCoverage = JSON.parse(localStorage.getItem("apt-game-coverage") || "null");
    if (cachedCoverage?.report) renderCoverage(cachedCoverage.report, true);
  } catch { /* Ignore malformed local cache. */ }
}

async function refreshAll({ forceCoverage = false } = {}) {
  if (state.busy) return;
  state.busy = true;
  const button = $("refresh-button");
  button.disabled = true;
  updateConnection("Refreshing GitHub", "loading");
  clearError();
  try {
    const runs = await fetchRuns();
    renderRuns(runs);
    const latestSha = String(runs[0]?.head_sha || "");
    const coverageDue = forceCoverage || !state.lastCoverageFetch || Date.now() - state.lastCoverageFetch > 5 * 60_000 || (latestSha && state.coverageSha && latestSha !== state.coverageSha);
    if (coverageDue) await fetchCoverage();
    $("updated-at").textContent = `Last sync ${new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit", second: "2-digit" })}`;
  } catch (error) {
    const rateNote = error.rate ? ` ${error.rate}.` : "";
    showError(`${error.message}${rateNote} The dashboard will retry automatically.`);
    updateConnection("Using last known data", "error");
    if (!state.runs.length) restoreCached();
    if (!state.lastCoverageFetch) {
      try { await fetchCoverage(); } catch { /* Keep cached report if the network is unavailable. */ }
    }
    $("updated-at").textContent = state.lastRunsFetch ? `Last successful sync ${relativeTime(state.lastRunsFetch)}` : "Waiting for connection";
  } finally {
    state.busy = false;
    button.disabled = false;
  }
}

$("refresh-button").addEventListener("click", () => refreshAll({ forceCoverage: true }));
restoreCached();
refreshAll({ forceCoverage: true });
window.setInterval(() => refreshAll(), POLL_MS);
