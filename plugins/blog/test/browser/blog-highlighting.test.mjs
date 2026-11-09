import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { after, before, test } from "node:test";
import { chromium } from "playwright";

const source = readFileSync(
  new URL("../../public/blog.js", import.meta.url),
  "utf8"
);
const assets = new URL(
  "../../../../frontend/discourse/node_modules/@highlightjs/cdn-assets/",
  import.meta.url
);
const core = readFileSync(
  new URL("../../vendor/highlightjs/core.min.js", import.meta.url),
  "utf8"
);
const languages = `export default function(hljs) {${["ruby", "javascript"]
  .map((language) =>
    readFileSync(new URL(`languages/${language}.min.js`, assets), "utf8")
  )
  .join("\n")}}`;
let browser;

before(async () => {
  browser = await chromium.launch({ args: ["--no-sandbox"] });
});
after(async () => browser?.close());

async function reader(
  t,
  content,
  { auto = false, fail = false, article = true } = {}
) {
  const page = await browser.newPage();
  t.after(() => page.close());
  const requests = [];
  await page.route("https://blog.example.com/**", async (route) => {
    const path = new URL(route.request().url()).pathname;
    if (path === "/blog.js") {
      return route.fulfill({
        contentType: "application/javascript",
        body: source,
      });
    }
    if (path === "/core.js") {
      requests.push("core");
      return fail
        ? route.abort()
        : route.fulfill({ contentType: "application/javascript", body: core });
    }
    return route.fulfill({
      contentType: "text/html",
      headers: {
        "Content-Security-Policy":
          "script-src 'nonce-test' 'strict-dynamic'; object-src 'none'; base-uri 'none'",
      },
      body: `<!doctype html><body data-blog-highlight-core-url="https://blog.example.com/core.js"
        data-blog-highlight-languages-url="https://forum.example.com/languages.js"
        data-blog-highlight-auto="${auto}">
        <script nonce="test">window.requestIdleCallback = callback => { window.runHighlight = callback; };</script>
        <main ${article ? 'class="blog-article__body"' : ""}>${content}</main>
        <script nonce="test" src="/blog.js" defer></script>`,
    });
  });
  await page.route("https://forum.example.com/languages.js", (route) => {
    requests.push("languages");
    return route.fulfill({
      contentType: "application/javascript",
      headers: { "Access-Control-Allow-Origin": "*" },
      body: languages,
    });
  });
  await page.goto("https://blog.example.com/");
  return { page, requests };
}

test("defers modules until idle, highlights aliases, and keeps HTML-shaped code inert", async (t) => {
  const { page, requests } = await reader(
    t,
    `
    <pre><code class="lang-rb">puts "hello"</code></pre>
    <pre><code class="language-js">const html = '&lt;img src=x onerror=alert(1)&gt;';</code></pre>
  `
  );
  assert.deepEqual(requests, []);
  await page.evaluate(() => window.runHighlight());
  assert.deepEqual(requests.sort(), ["core", "languages"]);
  assert.equal(await page.locator("code[data-highlighted=yes]").count(), 2);
  assert.ok(await page.locator(".hljs-string").count());
  assert.equal(await page.locator("code img").count(), 0);
  assert.equal(
    await page.locator("code").nth(1).textContent(),
    "const html = '<img src=x onerror=alert(1)>';"
  );
});

test("preserves numbered onebox lines, blank lines, and multiline token context", async (t) => {
  const { page } = await reader(
    t,
    `<pre class="onebox"><code class="lang-ruby">
    <ol class="lines" start="91"><li>message = "first</li><li></li><li class="selected">  last"</li></ol>
  </code></pre>`
  );
  await page.evaluate(() => window.runHighlight());
  assert.equal(await page.locator("ol").getAttribute("start"), "91");
  assert.deepEqual(await page.locator("li").allTextContents(), [
    'message = "first',
    "",
    '  last"',
  ]);
  assert.equal(
    await page.locator("li.selected .hljs-string").textContent(),
    '  last"'
  );
});

test("avoids downloads on pages without eligible code", async (t) => {
  for (const options of [
    { content: "<p>No code</p>" },
    {
      content: '<pre><code class="lang-ruby">puts 1</code></pre>',
      article: false,
    },
    { content: "<pre><code>puts 1</code></pre>" },
    { content: '<pre><code class="lang-text">puts 1</code></pre>' },
    {
      content:
        '<pre class="nohighlight"><code class="lang-ruby">puts 1</code></pre>',
    },
    {
      content:
        '<pre><code class="lang-ruby" data-highlighted="yes">puts 1</code></pre>',
    },
    {
      content: `<pre><code class="lang-ruby">${"x".repeat(30001)}</code></pre>`,
    },
  ]) {
    const { page, requests } = await reader(t, options.content, options);
    assert.equal(
      await page.evaluate(() => typeof window.runHighlight),
      "undefined"
    );
    assert.deepEqual(requests, []);
  }
});

test("supports auto detection without changing unknown languages or embedded markup", async (t) => {
  const { page } = await reader(
    t,
    `
    <pre><code>const message = "hello"; console.log(message);</code></pre>
    <pre><code class="lang-auto">const greeting = "hello"; console.log(greeting);</code></pre>
    <pre><code class="lang-unknown">leave me alone</code></pre>
    <pre><code class="lang-ruby"><a href="/example">puts</a> 1</code></pre>
  `,
    { auto: true }
  );
  await page.evaluate(() => window.runHighlight());
  assert.equal(await page.locator("code[data-highlighted=yes]").count(), 2);
  assert.equal(
    await page.locator(".lang-unknown").textContent(),
    "leave me alone"
  );
  assert.equal(await page.locator("code a").getAttribute("href"), "/example");
});

test("leaves readable code when the highlighter cannot be loaded", async (t) => {
  const { page } = await reader(
    t,
    '<pre><code class="lang-ruby">puts "hello"</code></pre>',
    { fail: true }
  );
  const errors = [];
  page.on("pageerror", (error) => errors.push(error.message));
  await page.evaluate(() => window.runHighlight());
  assert.equal(await page.locator("code").textContent(), 'puts "hello"');
  assert.equal(await page.locator("code[data-highlighted]").count(), 0);
  assert.deepEqual(errors, []);
});
