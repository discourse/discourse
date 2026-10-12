// Copies js files out of node_modules for Rails to use

import { copyFile, mkdir, readdir, rm, stat } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const DESTINATION = join(ROOT, "vendor/runtime_node_modules");

const CONCURRENCY = 16;

const FILES = {
  "highlightjs/languages":
    "frontend/discourse/node_modules/@highlightjs/cdn-assets/languages",
  "moment/moment.js": "frontend/discourse/node_modules/moment/moment.js",
  "moment/locale": "frontend/discourse/node_modules/moment/locale",
  "moment-timezone/moment-timezone-with-data.js":
    "frontend/discourse/node_modules/moment-timezone/builds/moment-timezone-with-data.js",
  "moment-timezone-names/locales":
    "node_modules/@discourse/moment-timezone-names-translations/locales",
  "qunit/qunit.css": "frontend/discourse/node_modules/qunit/qunit/qunit.css",
};

async function collect(source, target, files) {
  if (!(await stat(source)).isDirectory()) {
    files.push([source, target]);
    return;
  }

  await mkdir(target, { recursive: true });
  const entries = await readdir(source);
  await Promise.all(
    entries.map((entry) =>
      collect(join(source, entry), join(target, entry), files)
    )
  );
}

const files = [];

await rm(DESTINATION, { force: true, recursive: true });

for (const [destination, source] of Object.entries(FILES)) {
  const target = join(DESTINATION, destination);
  await mkdir(dirname(target), { recursive: true });
  await collect(join(ROOT, source), target, files);
}

await Promise.all(
  Array.from({ length: CONCURRENCY }, async () => {
    for (let file = files.pop(); file; file = files.pop()) {
      await copyFile(...file);
    }
  })
);
