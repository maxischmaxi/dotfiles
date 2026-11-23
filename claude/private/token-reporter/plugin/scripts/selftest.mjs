#!/usr/bin/env node
// selftest.mjs — prueft die reinen Funktionen von report-tokens.mjs ohne Netzwerk.
// Aufruf: node selftest.mjs   (Exit 0 = ok, Exit 1 = Fehler)

import assert from 'node:assert/strict'
import { sumUsageFromText, buildPayload, resolveConfig, parseArgs } from './report-tokens.mjs'

let passed = 0
function check(name, fn) {
  try {
    fn()
    passed++
    console.log(`  ok  - ${name}`)
  } catch (err) {
    console.error(`  FAIL - ${name}: ${err.message}`)
    process.exitCode = 1
  }
}

// Synthetisches Transcript: 1 User-Zeile (zaehlt nicht) + 2 Assistant-Zeilen.
const transcript = [
  JSON.stringify({ type: 'user', message: { role: 'user', content: 'hi' } }),
  JSON.stringify({
    type: 'assistant',
    message: {
      role: 'assistant',
      model: 'claude-opus-4-8',
      usage: { input_tokens: 10, output_tokens: 20, cache_creation_input_tokens: 100, cache_read_input_tokens: 50 },
    },
  }),
  '',
  'kaputte zeile { nicht json',
  JSON.stringify({
    type: 'assistant',
    message: {
      role: 'assistant',
      model: 'claude-opus-4-8',
      usage: { input_tokens: 5, output_tokens: 7, cache_read_input_tokens: 200 },
    },
  }),
].join('\n')

check('summiert nur Assistant-usage und ignoriert kaputte Zeilen', () => {
  const u = sumUsageFromText(transcript)
  assert.equal(u.input, 15)
  assert.equal(u.output, 27)
  assert.equal(u.cache_creation, 100)
  assert.equal(u.cache_read, 250)
  assert.equal(u.messages, 2)
  assert.equal(u.total, 15 + 27 + 100 + 250)
  // billed_input = 15 + 100*0.25 + 250*0.10 = 65
  assert.equal(u.billed_input, 65)
  assert.deepEqual(u.models, ['claude-opus-4-8'])
})

check('leeres Transcript -> Nullen', () => {
  const u = sumUsageFromText('')
  assert.equal(u.total, 0)
  assert.equal(u.messages, 0)
  assert.deepEqual(u.models, [])
})

check('buildPayload setzt final=true nur bei SessionEnd', () => {
  const usage = sumUsageFromText(transcript)
  const stop = buildPayload({ event: 'Stop', hookInput: { session_id: 's1' }, usage, project: { name: 'p' } })
  assert.equal(stop.final, false)
  assert.equal(stop.event, 'Stop')
  assert.equal(stop.tokens.total, usage.total)
  assert.equal(stop.session_id, 's1')

  const end = buildPayload({ event: 'SessionEnd', hookInput: { reason: 'logout' }, usage, project: { name: 'p' } })
  assert.equal(end.final, true)
  assert.equal(end.end_reason, 'logout')
})

check('resolveConfig liest env und Defaults', () => {
  const c = resolveConfig({ TOKEN_REPORTER_URL: 'https://x/y', TOKEN_REPORTER_ON_STOP: '0' })
  assert.equal(c.url, 'https://x/y')
  assert.equal(c.onStop, false)
  assert.equal(c.onSessionEnd, true)
  assert.equal(c.timeoutMs, 5000)
})

check('resolveConfig: CLI-opts haben Vorrang vor env', () => {
  const c = resolveConfig({ TOKEN_REPORTER_URL: 'https://env' }, { url: 'https://cli' })
  assert.equal(c.url, 'https://cli')
})

check('parseArgs erkennt Flags und Optionen', () => {
  const { flags, opts } = parseArgs(['--dry-run', '--transcript', '/tmp/t.jsonl', '--event', 'SessionEnd'])
  assert.equal(flags.dryRun, true)
  assert.equal(opts.transcript, '/tmp/t.jsonl')
  assert.equal(opts.event, 'SessionEnd')
})

console.log(`\n${passed} Checks ok${process.exitCode ? ', MIT FEHLERN' : ''}`)
