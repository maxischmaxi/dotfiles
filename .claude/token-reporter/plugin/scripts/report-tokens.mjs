#!/usr/bin/env node
// report-tokens.mjs
//
// Liest den Hook-Input (stdin oder CLI-Args), berechnet den Token-Verbrauch der
// aktuellen Session aus dem Transcript und meldet ihn pro Projekt an eine REST-API.
//
// Wichtigster Grundsatz: blockiert oder bricht Claude Code niemals ab. Alle Fehler
// werden abgefangen, der Prozess endet immer mit Exit-Code 0.
//
// Konfiguration ausschliesslich ueber Environment-Variablen (siehe README):
//   TOKEN_REPORTER_URL              Ziel-Endpoint (Pflicht; fehlt sie -> No-Op)
//   TOKEN_REPORTER_TOKEN            optionaler Bearer-Token (Authorization-Header)
//   TOKEN_REPORTER_PROJECT          optionaler Projekt-Name (ueberschreibt Git/cwd)
//   TOKEN_REPORTER_TIMEOUT_MS       HTTP-Timeout in ms (Default 5000)
//   TOKEN_REPORTER_ON_STOP          "0" deaktiviert das Melden nach jedem Turn
//   TOKEN_REPORTER_ON_SESSION_END   "0" deaktiviert das Melden am Session-Ende
//   TOKEN_REPORTER_DEBUG            "1" schreibt ein Debug-Log

import { readFileSync, appendFileSync, existsSync } from 'node:fs'
import { execFileSync } from 'node:child_process'
import { basename, join } from 'node:path'
import { tmpdir } from 'node:os'
import { pathToFileURL } from 'node:url'

const CLIENT = 'claude-code-token-reporter/1.0.0'

// ---- CLI-Args ---------------------------------------------------------------

export function parseArgs(argv) {
  const flags = {}
  const opts = {}
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i]
    if (a === '--dry-run' || a === '--print') flags.dryRun = true
    else if (a === '--ping') flags.ping = true
    else if (a === '--no-stdin') flags.noStdin = true
    else if (a.startsWith('--')) {
      const key = a.slice(2)
      const next = argv[i + 1]
      const val = next !== undefined && !next.startsWith('--') ? argv[++i] : ''
      opts[key] = val
    }
  }
  return { flags, opts }
}

// ---- Konfiguration ----------------------------------------------------------

function envFlag(value, fallback) {
  if (value === undefined || value === '') return fallback
  return !['0', 'false', 'no', 'off'].includes(String(value).toLowerCase())
}

export function resolveConfig(env = {}, opts = {}) {
  return {
    url: (opts.url || env.TOKEN_REPORTER_URL || '').trim(),
    token: (opts.token || env.TOKEN_REPORTER_TOKEN || '').trim(),
    projectOverride: (opts.project || env.TOKEN_REPORTER_PROJECT || '').trim(),
    timeoutMs: Number(env.TOKEN_REPORTER_TIMEOUT_MS) > 0 ? Number(env.TOKEN_REPORTER_TIMEOUT_MS) : 5000,
    onStop: envFlag(env.TOKEN_REPORTER_ON_STOP, true),
    onSessionEnd: envFlag(env.TOKEN_REPORTER_ON_SESSION_END, true),
    debug: envFlag(env.TOKEN_REPORTER_DEBUG, false),
  }
}

function debugLog(cfg, ...parts) {
  if (!cfg.debug) return
  try {
    const dir = process.env.CLAUDE_PLUGIN_DATA || tmpdir()
    appendFileSync(join(dir, 'token-reporter.log'), `[${new Date().toISOString()}] ${parts.join(' ')}\n`)
  } catch {
    // Logging darf niemals den Reporter stoeren.
  }
}

// ---- Token-Summierung aus dem Transcript ------------------------------------

// Summiert message.usage ueber alle Assistant-Zeilen. Eine JSONL-Zeile = ein
// API-Request; es werden nur die Top-Level-usage-Felder gezaehlt (nicht die
// bereits darin aggregierten iterations), um Doppelzaehlung zu vermeiden.
export function sumUsageFromText(text) {
  const totals = { input: 0, output: 0, cache_creation: 0, cache_read: 0, messages: 0 }
  const models = new Set()

  for (const line of String(text).split('\n')) {
    const trimmed = line.trim()
    if (!trimmed) continue
    let event
    try {
      event = JSON.parse(trimmed)
    } catch {
      continue
    }
    const message = event && event.message
    const usage = message && message.usage
    const role = message && message.role
    if (!usage || (event.type !== 'assistant' && role !== 'assistant')) continue

    totals.input += usage.input_tokens || 0
    totals.output += usage.output_tokens || 0
    totals.cache_creation += usage.cache_creation_input_tokens || 0
    totals.cache_read += usage.cache_read_input_tokens || 0
    totals.messages += 1
    if (message.model) models.add(message.model)
  }

  const total = totals.input + totals.output + totals.cache_creation + totals.cache_read
  // Abgerechnete Input-Tokens: Cache-Writes zu 25 %, Cache-Reads zu 10 %.
  const billed_input = Math.round(totals.input + totals.cache_creation * 0.25 + totals.cache_read * 0.1)

  return { ...totals, total, billed_input, models: [...models] }
}

export function emptyUsage() {
  return { input: 0, output: 0, cache_creation: 0, cache_read: 0, messages: 0, total: 0, billed_input: 0, models: [] }
}

// ---- Projekt-Erkennung ------------------------------------------------------

function git(cwd, args) {
  try {
    return execFileSync('git', ['-C', cwd, ...args], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
      timeout: 2000,
    }).trim()
  } catch {
    return ''
  }
}

export function resolveProject(cwd, override) {
  const safeCwd = cwd || process.cwd()
  const toplevel = git(safeCwd, ['rev-parse', '--show-toplevel'])
  const remote = git(safeCwd, ['config', '--get', 'remote.origin.url'])
  const branch = git(safeCwd, ['rev-parse', '--abbrev-ref', 'HEAD'])
  const name = (override || (toplevel ? basename(toplevel) : basename(safeCwd)) || safeCwd)
  return {
    name,
    path: toplevel || safeCwd,
    git_remote: remote || null,
    git_branch: branch && branch !== 'HEAD' ? branch : null,
  }
}

// ---- Payload + Versand ------------------------------------------------------

export function buildPayload({ event, hookInput, usage, project, turnTokens }) {
  return {
    client: CLIENT,
    event,
    final: event === 'SessionEnd',
    reported_at: new Date().toISOString(),
    session_id: hookInput.session_id || null,
    cwd: hookInput.cwd || null,
    transcript_path: hookInput.transcript_path || null,
    end_reason: hookInput.reason || null,
    project,
    models: usage.models,
    tokens: {
      input: usage.input,
      output: usage.output,
      cache_creation: usage.cache_creation,
      cache_read: usage.cache_read,
      total: usage.total,
      billed_input: usage.billed_input,
      messages: usage.messages,
    },
    turn_tokens: turnTokens || null,
  }
}

async function postReport(cfg, payload) {
  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), cfg.timeoutMs)
  try {
    const headers = { 'content-type': 'application/json', 'user-agent': CLIENT }
    if (cfg.token) headers.authorization = `Bearer ${cfg.token}`
    const res = await fetch(cfg.url, {
      method: 'POST',
      headers,
      body: JSON.stringify(payload),
      signal: controller.signal,
    })
    return { ok: res.ok, status: res.status }
  } catch (err) {
    return { ok: false, error: String((err && err.message) || err) }
  } finally {
    clearTimeout(timer)
  }
}

// ---- Hauptablauf ------------------------------------------------------------

async function main() {
  const { flags, opts } = parseArgs(process.argv.slice(2))
  const cfg = resolveConfig(process.env, opts)

  // --ping: nur einen Test-Request senden, kein Transcript noetig.
  if (flags.ping) {
    const project = resolveProject(opts.cwd || process.cwd(), cfg.projectOverride)
    const payload = { client: CLIENT, event: 'ping', reported_at: new Date().toISOString(), project }
    if (!cfg.url) {
      process.stdout.write('TOKEN_REPORTER_URL ist nicht gesetzt - kein Ziel zum Pingen.\n')
      return
    }
    const result = await postReport(cfg, payload)
    process.stdout.write(`Ping -> ${cfg.url}\n${JSON.stringify(result)}\n`)
    return
  }

  // Hook-Input aus CLI-Args (Test/Dry-Run) oder von stdin lesen.
  let hookInput = {}
  if (opts.transcript || flags.noStdin) {
    hookInput = {
      hook_event_name: opts.event || 'Stop',
      session_id: opts.session || null,
      transcript_path: opts.transcript || null,
      cwd: opts.cwd || process.cwd(),
    }
  } else {
    try {
      hookInput = JSON.parse(readFileSync(0, 'utf8') || '{}')
    } catch (err) {
      debugLog(cfg, 'stdin konnte nicht gelesen/geparst werden:', err?.message)
      return
    }
  }

  const event = hookInput.hook_event_name || opts.event || 'Stop'

  // Event-Gating ueber Config.
  if (event === 'Stop' && !cfg.onStop) return debugLog(cfg, 'Stop-Reporting deaktiviert')
  if (event === 'SessionEnd' && !cfg.onSessionEnd) return debugLog(cfg, 'SessionEnd-Reporting deaktiviert')

  // Token-Verbrauch aus dem Transcript berechnen.
  let usage = emptyUsage()
  const transcriptPath = hookInput.transcript_path
  if (transcriptPath && existsSync(transcriptPath)) {
    try {
      usage = sumUsageFromText(readFileSync(transcriptPath, 'utf8'))
    } catch (err) {
      debugLog(cfg, 'Transcript konnte nicht gelesen werden:', err?.message)
    }
  } else {
    debugLog(cfg, 'kein Transcript gefunden:', transcriptPath)
  }

  const project = resolveProject(hookInput.cwd, cfg.projectOverride)
  const payload = buildPayload({ event, hookInput, usage, project, turnTokens: hookInput.token_usage })

  if (flags.dryRun) {
    process.stdout.write(JSON.stringify(payload, null, 2) + '\n')
    return
  }

  if (!cfg.url) return debugLog(cfg, 'keine URL konfiguriert -> No-Op')

  const result = await postReport(cfg, payload)
  debugLog(cfg, 'Report gesendet:', event, project.name, 'total=' + usage.total, JSON.stringify(result))
}

// Nur ausfuehren, wenn direkt gestartet (nicht beim Import durch den Selftest).
const invokedDirectly = (() => {
  try {
    return process.argv[1] && pathToFileURL(process.argv[1]).href === import.meta.url
  } catch {
    return false
  }
})()

if (invokedDirectly) {
  main()
    .catch(() => {
      // niemals blockieren oder mit Fehler enden
    })
    .finally(() => process.exit(0))
}
