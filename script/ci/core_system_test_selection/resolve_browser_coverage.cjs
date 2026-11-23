const fs = require("node:fs");
const path = require("node:path");
const { spawn, execFileSync } = require("node:child_process");
const readline = require("node:readline");
const { SourceMapConsumer } = require(
  process.cwd() + "/tmp/core-system-selection/source-map-js"
);

const directory = process.argv[2];
const activeAttempts = process.env.SYSTEM_COVERAGE_ACTIVE_ATTEMPTS
  ? JSON.parse(
      fs.readFileSync(process.env.SYSTEM_COVERAGE_ACTIVE_ATTEMPTS, "utf8")
    )
  : null;
const tracked = execFileSync("git", ["ls-files", "-z"], {
  encoding: "utf8",
  maxBuffer: 8 * 1024 * 1024,
})
  .split("\0")
  .filter(Boolean);
const trackedSet = new Set(tracked);
const suffixes = new Map();
for (const file of tracked) {
  const segments = file.split("/");
  for (let index = 0; index < segments.length - 1; index++) {
    const suffix = segments.slice(index).join("/");
    if (suffixes.has(suffix)) suffixes.set(suffix, null);
    else suffixes.set(suffix, file);
  }
}

function originalPath(source) {
  const segments = source
    .split("/")
    .filter((part) => part && part !== ".." && part !== ".");
  for (let index = 0; index < segments.length - 1; index++) {
    const match = suffixes.get(segments.slice(index).join("/"));
    if (match) return match;
  }
}

const compiled = new Map();
const unresolved = new Set();
const assetMapReferences = new Map();
const assets = "frontend/discourse/dist/assets";
const scriptPaths = new Map();
function scriptPath(filename) {
  if (!scriptPaths.has(filename)) {
    const modern = path.join(assets, "js", filename);
    const flat = path.join(assets, filename.replace(/\.(?:br|gz)\.js$/, ".js"));
    scriptPaths.set(
      filename,
      filename.startsWith("chunk.") && fs.existsSync(flat) ? flat : modern
    );
  }
  return scriptPaths.get(filename);
}

function pointsFor(sourceFile, mapFile) {
  if (compiled.has(mapFile)) return compiled.get(mapFile);
  if (!fs.existsSync(sourceFile) || !fs.existsSync(mapFile)) {
    unresolved.add(mapFile);
    compiled.set(mapFile, []);
    return [];
  }

  const source = fs.readFileSync(sourceFile, "utf8").replace(/^\uFEFF/, "");
  const starts = [0];
  for (let index = 0; index < source.length; index++) {
    if (source.charCodeAt(index) === 10) starts.push(index + 1);
  }

  const consumer = new SourceMapConsumer(
    JSON.parse(fs.readFileSync(mapFile, "utf8"))
  );
  const files = new Map(
    consumer.sources.map((name) => [name, originalPath(name)])
  );
  const points = [];
  consumer.eachMapping((mapping) => {
    const file = files.get(mapping.source);
    const lineStart = starts[mapping.generatedLine - 1];
    if (file && lineStart !== undefined) {
      points.push([lineStart + mapping.generatedColumn, file]);
    }
  });
  compiled.set(mapFile, points);
  return points;
}

function record(points, ranges, test, index) {
  if (!points.length || !ranges.some((range) => range.count > 0)) return;
  ranges.sort(
    (left, right) =>
      left.startOffset - right.startOffset || right.endOffset - left.endOffset
  );
  let cursor = 0;
  const active = [];
  for (const [offset, file] of points) {
    while (cursor < ranges.length && ranges[cursor].startOffset <= offset) {
      const range = ranges[cursor++];
      while (
        active.length &&
        active[active.length - 1].endOffset <= range.startOffset
      )
        active.pop();
      active.push(range);
    }
    while (active.length && active[active.length - 1].endOffset <= offset)
      active.pop();
    if (active.length === 0 && cursor === ranges.length) break;
    if (!active[active.length - 1]?.count) continue;
    if (!index.has(file)) index.set(file, new Set());
    index.get(file).add(test);
  }
}

function metadataIndex(prefix, field) {
  const index = new Map();
  for (const name of fs
    .readdirSync(directory)
    .filter(
      (name) => name.startsWith(prefix + "-") && name.endsWith(".jsonl")
    )) {
    for (const line of fs
      .readFileSync(path.join(directory, name), "utf8")
      .trim()
      .split("\n")
      .filter(Boolean)) {
      const row = JSON.parse(line);
      index.set([row.id, row.page, row[field]].join("\0"), row);
    }
  }
  return index;
}

async function main() {
  const index = new Map();
  const scriptMetadata = metadataIndex("scripts", "script_id");
  const scriptsByUrl = new Map();
  for (const metadata of scriptMetadata.values()) {
    const key = [metadata.id, metadata.page, metadata.url].join("\0");
    if (!scriptsByUrl.has(key)) scriptsByUrl.set(key, metadata);
    else if (scriptsByUrl.get(key)?.source_map_url !== metadata.source_map_url)
      scriptsByUrl.set(key, null);
  }
  const styleMetadata = metadataIndex("styles", "style_sheet_id");
  const localPages = new Set();
  const localHost = (hostname) =>
    hostname === "localhost" ||
    hostname.endsWith(".localhost") ||
    hostname === "127.0.0.1" ||
    hostname === "[::1]";
  const providerFile = "lib/discourse_id.rb";
  const provider =
    fs.existsSync(providerFile) &&
    fs
      .readFileSync(providerFile, "utf8")
      .match(
        /^\s*DEFAULT_PROVIDER_URL\s*=\s*["'](https:\/\/[^"'\s]+)["']\s*$/m
      );
  const identityHost = provider ? new URL(provider[1]).hostname : null;
  for (const meta of styleMetadata.values()) {
    const asset = new URL(meta.url || "about:blank", "http://test.localhost");
    if (localHost(asset.hostname) && asset.pathname.includes("/stylesheets/")) {
      localPages.add(meta.id + "\0" + meta.page);
    }
  }
  const examples = new Set();
  const gzipFiles = fs
    .readdirSync(directory)
    .filter((name) => /^browser-.*\.jsonl\.gz$/.test(name));
  if (!gzipFiles.length) throw new Error("No browser coverage records");
  for (const filename of gzipFiles) {
    const command = spawn("gzip", ["-dc", path.join(directory, filename)], {
      stdio: ["ignore", "pipe", "inherit"],
    });
    const completed = new Promise((resolve, reject) => {
      command.on("error", reject);
      command.on("close", (code) =>
        code === 0 ? resolve() : reject(new Error("gzip failed: " + filename))
      );
    });
    for await (const line of readline.createInterface({
      input: command.stdout,
    })) {
      const row = JSON.parse(line);
      const allowed =
        activeAttempts && [].concat(activeAttempts[row.id] || []).map(String);
      if (allowed && !allowed.includes(filename.match(/^browser-(\d+)-/)[1]))
        continue;
      const test = row.id.split("[")[0].replace(/^\.\//, "");
      if (!trackedSet.has(test)) throw new Error("Unknown spec " + test);
      examples.add(row.id);

      const javascript =
        row.javascript ||
        (row.javascript_entries || []).flatMap((entry) => {
          const directMetadata = scriptMetadata.get(
            [row.id, row.page, entry.scriptId].join("\0")
          );
          const metadata =
            directMetadata ||
            scriptsByUrl.get([row.id, row.page, entry.url].join("\0"));
          const filename = path.basename(new URL(entry.url).pathname);
          if (!assetMapReferences.has(filename)) {
            const asset = scriptPath(filename);
            const annotation = fs.existsSync(asset)
              ? fs
                  .readFileSync(asset, "utf8")
                  .slice(-1024)
                  .match(/sourceMappingURL=([^\s*]+)/)?.[1]
              : undefined;
            assetMapReferences.set(filename, annotation);
          }
          const annotation = assetMapReferences.get(filename);
          if (
            metadata?.source_map_url &&
            annotation &&
            path.basename(metadata.source_map_url) !== path.basename(annotation)
          )
            throw new Error("Source map references disagree: " + filename);
          const map = metadata?.source_map_url || annotation;
          const canonical = path.basename(scriptPath(filename));
          if (canonical !== filename) {
            if (
              !metadata?.source_map_url ||
              !annotation ||
              path.basename(map) !== canonical + ".map"
            )
              throw new Error("Unverified encoded script: " + filename);
          }
          if (!map) {
            if (!metadata) unresolved.add("script-metadata:" + entry.scriptId);
            return [];
          }
          return [
            [
              filename,
              path.basename(map.split("?")[0]),
              entry.functions.flatMap((fn) => fn.ranges),
            ],
          ];
        });
      const css =
        row.css ||
        (row.css_rule_usage || []).flatMap((rule) => {
          if (!rule.used) return [];
          const metadata = styleMetadata.get(
            [row.id, row.page, rule.styleSheetId].join("\0")
          );
          if (!metadata) {
            unresolved.add("style-metadata:" + rule.styleSheetId);
            return [];
          }
          const asset = new URL(
            metadata.url || "about:blank",
            "http://test.localhost"
          );
          const pathname = asset.pathname;
          if (!pathname.includes("/stylesheets/")) return [];
          const filename = path.basename(pathname);
          const sourceFile = path.join(
            directory,
            "stylesheets-" + row.worker,
            filename
          );
          const document = new URL(
            row.url || "about:blank",
            "http://test.localhost"
          );
          // Discourse puts the owning site in __ws on CDN stylesheets. Preserve
          // local CDN assets and demand maps for missing assets of unknown origin.
          if (
            localPages.has(row.id + "\0" + row.page) &&
            document.protocol === "https:" &&
            document.hostname === identityHost &&
            !localHost(document.hostname) &&
            !localHost(asset.hostname) &&
            asset.searchParams.get("__ws") === document.hostname &&
            !fs.existsSync(sourceFile)
          ) {
            return [];
          }
          let annotation = metadata.source_map_url;
          if (!annotation && fs.existsSync(sourceFile))
            annotation = fs
              .readFileSync(sourceFile, "utf8")
              .slice(-1024)
              .match(/sourceMappingURL=([^\s*]+)/)?.[1];
          if (!annotation) return [];
          return [
            [
              filename,
              path.basename(annotation.split("?")[0]),
              [{ start: rule.startOffset, end: rule.endOffset }],
            ],
          ];
        });
      for (const [script, map, ranges] of javascript) {
        const sourceFile = scriptPath(script);
        const mapDirectory =
          path.dirname(sourceFile) === assets
            ? assets
            : path.join(assets, "map");
        const points = pointsFor(sourceFile, path.join(mapDirectory, map));
        record(points, ranges, test, index);
      }
      const cssGroups = new Map();
      for (const [stylesheet, map, ranges] of css) {
        const key = stylesheet + "\0" + map;
        if (!cssGroups.has(key)) cssGroups.set(key, [stylesheet, map, []]);
        cssGroups.get(key)[2].push(...ranges);
      }
      for (const [stylesheet, map, ranges] of cssGroups.values()) {
        const base = path.join(directory, "stylesheets-" + row.worker);
        const points = pointsFor(
          path.join(base, stylesheet),
          path.join(base, map)
        );
        record(
          points,
          ranges.map((range) => ({
            startOffset: range.start,
            endOffset: range.end,
            count: 1,
          })),
          test,
          index
        );
      }
    }
    await completed;
  }
  const testsBySource = Object.fromEntries(
    [...index]
      .sort(([left], [right]) => left.localeCompare(right))
      .map(([file, specs]) => [file, [...specs].sort()])
  );
  console.log(
    JSON.stringify({
      tests_by_source: testsBySource,
      observed_example_ids: [...examples].sort(),
      missing_asset_maps: [...unresolved].sort(),
    })
  );
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
