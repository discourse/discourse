#!/usr/bin/env node
/* eslint-disable no-console */

// Loads pages in headless Chromium against a running server and reports the
// JavaScript chunks the browser actually fetched, sized from the build report.

import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright";

const here = path.dirname(fileURLToPath(import.meta.url));
const DIST = path.resolve(here, "../../frontend/discourse/dist");
const manifest = JSON.parse(
  readFileSync(path.join(DIST, "manifest/manifest.json"), "utf8")
);
const report = JSON.parse(
  readFileSync(path.join(DIST, manifest.bundleAnalysis), "utf8")
);

const base =
  process.env.BASE_URL ??
  `http://localhost:${process.env.UNICORN_PORT ?? 3000}`;
const pages = process.argv.slice(2);
if (!pages.length) {
  pages.push("/", "/t/share-your-hallowe-en-pictures/60");
}

const browser = await chromium.launch({
  executablePath: process.env.CHROME_PATH,
});
let failed = false;

for (const url of pages) {
  const context = await browser.newContext();
  const page = await context.newPage();
  const scripts = new Set();
  const errors = [];

  page.on("response", (response) => {
    const u = new URL(response.url());
    if (u.pathname.includes("/assets/js/")) {
      scripts.add(u.pathname.slice(u.pathname.indexOf("assets/js/")));
    }
  });
  page.on("pageerror", (error) => errors.push(`pageerror: ${error.message}`));
  page.on("console", (message) => {
    if (message.type() === "error") {
      errors.push(`console: ${message.text()}`);
    }
  });

  const separator = url.includes("?") ? "&" : "?";
  await page.goto(`${base}${url}${separator}safe_mode=no_themes`, {
    waitUntil: "load",
    timeout: 90000,
  });
  const rendered = await page
    .waitForSelector(
      "#main-outlet .topic-list, #main-outlet .topic-post, #main-outlet .container",
      { timeout: 30000 }
    )
    .then(() => true)
    .catch(() => false);
  await page.waitForTimeout(3000);
  if (!rendered) {
    errors.push("main outlet never rendered a topic list, post, or container");
  }

  if (process.env.INTERACT && url.startsWith("/t/")) {
    const link = await page.$("[data-user-card]");
    if (link) {
      await link.click();
      const card = await page
        .waitForSelector("#user-card.show", { timeout: 15000 })
        .then(() => true)
        .catch(() => false);
      if (!card) {
        errors.push("user card did not open after clicking a user link");
      }
      await page.waitForTimeout(1000);
    }
  }

  let brotli = 0;
  let raw = 0;
  const unknown = [];
  const chunks = [];
  for (const file of scripts) {
    const chunk = report.chunks[file];
    if (!chunk) {
      unknown.push(file);
      continue;
    }
    brotli += chunk.brotliSize;
    raw += chunk.rawSize;
    chunks.push(`${String(chunk.brotliSize).padStart(8)}  ${file}`);
  }

  const title = await page.title();
  console.log(`${url}  "${title}"`);
  console.log(
    `  ${(brotli / 1024).toFixed(1)} KiB br, ${(raw / 1024).toFixed(1)} KiB raw, ${scripts.size} scripts`
  );
  if (process.env.VERBOSE) {
    console.log(
      chunks
        .sort()
        .reverse()
        .map((c) => `    ${c}`)
        .join("\n")
    );
  }
  if (unknown.length) {
    console.log(`  not in report: ${unknown.join(", ")}`);
  }
  if (errors.length) {
    failed = true;
    console.log(errors.map((e) => `  ${e}`).join("\n"));
  }
  await context.close();
}

await browser.close();
process.exit(failed ? 1 : 0);
