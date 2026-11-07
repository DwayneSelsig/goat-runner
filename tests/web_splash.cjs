const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const html = fs.readFileSync('assets/web/shell.html', 'utf8');
const script = html.match(/<script>\s*const GODOT_CONFIG = ([\s\S]*?)<\/script>/)[1];

async function run(fail) {
  const timers = [];
  const listeners = {};
  const elements = {};
  for (const id of ['status', 'status-progress', 'status-notice', 'splash-continue', 'fade']) {
    elements[id] = { style: {}, classList: { add() {}, remove() {} },
      addEventListener(name, fn) { this[name] = fn; },
      remove() { this.removed = true; }, removeAttribute() {}, appendChild() {}, lastChild: null };
  }
  class Engine {
    static getMissingFeatures() { return []; }
    startGame() { return fail ? Promise.reject(new Error('load failed')) : Promise.resolve(); }
  }
  const window = { goatSplashWaiting: true, addEventListener(name, fn) { listeners[name] = fn; } };
  const context = { Engine, window, document: { getElementById: id => elements[id], createTextNode() {}, createElement() {} },
    setTimeout: fn => { timers.push(fn); }, console: { error() {} }, Error };
  vm.runInNewContext(`const GODOT_CONFIG = {};${script.replace(/^.*?;\s*/, '')}`, context);
  const key = () => listeners.keydown({ code: 'Space', repeat: false, preventDefault() {}, stopImmediatePropagation() {} });
  key();
  elements['splash-continue'].click();
  assert.equal(timers.length, 0, 'Space must not continue while loading');
  await Promise.resolve();
  if (fail) {
    assert.equal(elements['splash-continue'].style.display, undefined);
    assert.equal(elements['status-notice'].style.display, 'block');
    return;
  }
  assert.equal(elements['splash-continue'].style.display, 'block');
  assert.equal(window.goatSplashWaiting, true);
  elements['splash-continue'].click();
  key();
  assert.equal(timers.length, 1, 'Continue must start only one fade');
  timers.shift()();
  assert.equal(elements.status.removed, true);
  assert.equal(window.goatSplashWaiting, true, 'Goat must wait through the fade-in');
  timers.shift()();
  assert.equal(window.goatSplashWaiting, false);
}
(async () => { await run(false); await run(true); console.log('Web splash test passed'); })().catch(error => { console.error(error); process.exitCode = 1; });
