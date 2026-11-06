// Captures the light and dark screenshots shown on the admin Themes cards for
// each included theme, through a signed preview of the local development site.
// Run from the repository root while the dev server is up:
//
//   node plugins/blog/script/capture-theme-screenshots.mjs
//
// The images show whatever articles the development site has, so publish a
// tidy set of sample articles first.
import { execFileSync } from "node:child_process";
import { mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright";

const OUTPUT = join(
  dirname(fileURLToPath(import.meta.url)),
  "../public/images/themes"
);

// 1280×960 CSS pixels, saved at 800×600 to keep the files small.
const VIEWPORT = { width: 1280, height: 960 };
const SCALE = 0.625;

const previews = JSON.parse(
  execFileSync(
    "bin/rails",
    [
      "runner",
      "puts Blog::ThemePresets.all.to_h { |preset| [preset['id'], Blog::ThemePreview.url(Blog::ThemePreview.token_for(preset))] }.to_json",
    ],
    { env: { ...process.env, LOAD_PLUGINS: "1" }, encoding: "utf8" }
  )
    .trim()
    .split("\n")
    .at(-1)
);

const browser = await chromium.launch();

try {
  for (const [id, url] of Object.entries(previews)) {
    mkdirSync(join(OUTPUT, id), { recursive: true });

    for (const colorScheme of ["light", "dark"]) {
      const page = await browser.newPage({
        viewport: VIEWPORT,
        deviceScaleFactor: SCALE,
        colorScheme,
      });
      await page.goto(url, { waitUntil: "networkidle" });
      // Hides the preview notice and the development profiler badge.
      await page.addStyleTag({
        content: ".blog__preview, .profiler-results { display: none; }",
      });
      const path = join(OUTPUT, id, `${colorScheme}.jpg`);
      await page.screenshot({ path, type: "jpeg", quality: 82 });
      await page.close();
      // eslint-disable-next-line no-console
      console.log(`Captured ${path}`);
    }
  }
} finally {
  await browser.close();
}
