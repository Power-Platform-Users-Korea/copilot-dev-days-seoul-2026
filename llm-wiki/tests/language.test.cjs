const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const chapterIds = html => [...html.matchAll(/<section\b[^>]*\bid="([^"]+)"/g)].map(match => match[1]);

test('both languages retain matching navigation targets and executable lecture scripts', () => {
  const korean = read('index.html');
  const english = read('en/index.html');
  assert.match(korean, /<html lang="ko">/);
  assert.match(english, /<html lang="en">/);
  assert.deepEqual(chapterIds(english), chapterIds(korean));
  for (const html of [korean, english]) {
    assert.match(html, /hreflang="ko"/);
    assert.match(html, /hreflang="en"/);
    assert.match(html, /class="language-switcher"/);
    assert.equal((html.match(/aria-current="page"/g) || []).length, 1);
    const ids = [...html.split('<script>')[0].matchAll(/\sid="([^"]+)"/g)].map(match => match[1]);
    assert.equal(new Set(ids).size, ids.length, 'DOM IDs must be unique');
    for (const [, script] of html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)) {
      new vm.Script(script);
    }
  }
});

test('local page resources, downloads, and fragment links exist in both languages', () => {
  for (const page of ['index.html', 'en/index.html']) {
    const html = read(page);
    const markup = html.split('<script>')[0];
    const ids = new Set([...markup.matchAll(/\sid="([^"]+)"/g)].map(match => match[1]));
    for (const [, url] of markup.matchAll(/\b(?:href|src|data-shot)="([^"]+)"/g)) {
      if (/^(?:https?:|mailto:|data:)/.test(url)) continue;
      if (url.startsWith('#')) {
        assert.ok(ids.has(url.slice(1)), `${page}: missing target ${url}`);
        continue;
      }
      const local = path.resolve(root, path.dirname(page), url.split('#')[0]);
      assert.ok(fs.existsSync(local), `${page}: missing resource ${url}`);
    }
    for (const [, image] of html.matchAll(/['"]((?:\.\.\/)?images\/[^'"]+\.(?:png|webp))['"]/g)) {
      assert.ok(fs.existsSync(path.resolve(root, path.dirname(page), image)), `${page}: missing image ${image}`);
    }
  }
});

test('English setup commands use the English kit', () => {
  const html = read('en/index.html');
  assert.ok(html.includes('/llm-wiki/en/kit'));
  assert.ok(!html.includes("/llm-wiki/kit'"));
  for (const file of [
    'README.md', 'New-LlmWiki.ps1', 'Test-LlmWiki.ps1', 'Clear-Sample.ps1',
    'Export-WikiDocx.ps1', 'Publish-LlmWikiGitHub.ps1', 'Publish-LlmWikiSharePoint.ps1',
    'llm-wiki-kit.zip'
  ]) {
    assert.ok(fs.existsSync(path.join(root, 'en', 'kit', file)), `Missing English kit file: ${file}`);
  }
});

test('switcher preserves deep links and follows the visible chapter without storage or redirects', () => {
  for (const locale of ['ko', 'en']) {
    const base = `https://example.org/project/llm-wiki/${locale === 'en' ? 'en/' : ''}`;
    const links = [
      { href: new URL(locale === 'en' ? '../' : './', base).href },
      { href: new URL(locale === 'en' ? './' : 'en/', base).href }
    ];
    let chapter = null;
    let observer;
    const listeners = {};
    const location = { hash: '#ch3' };
    vm.runInNewContext(read('language-switcher.js'), {
      URL,
      location,
      document: {
        querySelectorAll: () => links,
        querySelector: selector => selector === '#trail' ? {} : chapter
      },
      addEventListener: (event, callback) => { listeners[event] = callback; },
      MutationObserver: class {
        constructor(callback) { observer = callback; }
        observe() {}
      }
    });
    assert.ok(links.every(link => new URL(link.href).hash === '#ch3'));
    chapter = { dataset: { id: 'ch7' } };
    observer();
    assert.ok(links.every(link => new URL(link.href).hash === '#ch7'));
    chapter = null;
    location.hash = '#top';
    listeners.hashchange();
    assert.ok(links.every(link => new URL(link.href).hash === '#top'));
    assert.equal(new URL(links[0].href).pathname, '/project/llm-wiki/');
    assert.equal(new URL(links[1].href).pathname, '/project/llm-wiki/en/');
  }
});
