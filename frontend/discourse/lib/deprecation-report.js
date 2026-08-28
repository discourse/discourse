"use strict";

const fs = require("fs");
const path = require("path");
const { SourceMapConsumer } = require("source-map-js");
const {
  ReportAccumulator,
  mergeReports,
  renderReportSummary,
} = require("./deprecation-report-format");

const REPO_ROOT = path.resolve(__dirname, "..", "..", "..");
const MAP_ROOTS = [
  path.join(REPO_ROOT, "frontend", "discourse", "dist", "assets", "map"),
  path.join(REPO_ROOT, "app", "assets", "generated"),
];
const PLUMBING_PATTERNS = [
  /\/app\/lib\/deprecated\.js$/,
  /\/app\/lib\/source-identifier\.js$/,
  /\/tests\/helpers\/deprecation-counter\.js$/,
  /\/tests\/helpers\/raise-on-deprecation\.js$/,
  /\/ember-source\/.*\/deprecate\.js$/,
  /\/@ember\/debug\//,
];
const DEPRECATION_WRAPPER_PATTERN = /(^|\/)app\/lib\/deprecated\.js$/;
const TEST_FILE_PATTERN = /\/(tests?|spec)\/.*-test\.(js|gjs|ts|gts)$/;
const MAX_RESOLVED_FRAMES = 60;

function normalizeFile(file) {
  if (!file) {
    return null;
  }

  const normalized = file.replaceAll("\\", "/").replace(/^\.\//, "");
  const pluginMatch = normalized.match(
    /(?:^|\/)discourse\/plugins\/([^/]+)\/(.+)$/
  );

  if (pluginMatch) {
    const [, plugin, rest] = pluginMatch;
    const candidates = [
      `plugins/${plugin}/assets/javascripts/${rest}`,
      `plugins/${plugin}/test/javascripts/${rest}`,
    ];

    return (
      candidates.find((candidate) =>
        fs.existsSync(path.join(REPO_ROOT, candidate))
      ) || candidates[0]
    );
  }

  return normalized;
}

function normalizeMappedSource(source, mapPath) {
  const normalized = source
    .replace(/^webpack:\/\/[^/]*\//, "")
    .replaceAll("\\", "/");
  const absolute = path.isAbsolute(normalized)
    ? normalized
    : path.resolve(path.dirname(mapPath), normalized);
  const relative = path.relative(REPO_ROOT, absolute);

  return normalizeFile(relative.startsWith("..") ? absolute : relative);
}

class SourceMap {
  #consumer;
  #mapPath;

  constructor(json, mapPath) {
    this.#consumer = new SourceMapConsumer(json);
    this.#mapPath = mapPath;
  }

  originalPositionFor(line, column) {
    let original;
    let approximate = false;

    for (let back = 0; back <= 10 && line - back >= 1; back++) {
      original = this.#consumer.originalPositionFor({
        line: line - back,
        column: back === 0 ? column - 1 : Number.MAX_SAFE_INTEGER,
        bias: SourceMapConsumer.GREATEST_LOWER_BOUND,
      });

      if (original.source) {
        approximate = back > 0;
        break;
      }
    }

    if (!original?.source) {
      return null;
    }

    const source = this.#consumer.sourceContentFor(original.source, true);
    const code = source?.split("\n")[original.line - 1];

    return {
      file: normalizeMappedSource(original.source, this.#mapPath),
      line: original.line,
      column: original.column + 1,
      code: code === undefined ? null : code.trim().slice(0, 200),
      approximate,
    };
  }
}

class SourceMapIndex {
  #byBasename;
  #cache = new Map();
  #mapRoots;

  constructor(mapRoots = MAP_ROOTS) {
    this.#mapRoots = mapRoots;
  }

  #index() {
    if (this.#byBasename) {
      return this.#byBasename;
    }

    this.#byBasename = new Map();
    for (const root of this.#mapRoots) {
      this.#walk(root);
    }
    return this.#byBasename;
  }

  #walk(directory, depth = 0) {
    if (depth > 6) {
      return;
    }

    let entries;
    try {
      entries = fs.readdirSync(directory, { withFileTypes: true });
    } catch {
      return;
    }

    for (const entry of entries) {
      const fullPath = path.join(directory, entry.name);
      if (entry.isDirectory()) {
        this.#walk(fullPath, depth + 1);
      } else if (entry.name.endsWith(".map")) {
        this.#byBasename.set(entry.name, fullPath);
      }
    }
  }

  forScript(scriptBasename) {
    if (this.#cache.has(scriptBasename)) {
      return this.#cache.get(scriptBasename);
    }

    const mapPath = this.#index().get(`${scriptBasename}.map`);
    let sourceMap = null;

    if (mapPath) {
      try {
        sourceMap = new SourceMap(
          JSON.parse(fs.readFileSync(mapPath, "utf8")),
          mapPath
        );
      } catch {
        sourceMap = null;
      }
    }

    this.#cache.set(scriptBasename, sourceMap);
    return sourceMap;
  }
}

const STACK_FRAME_PATTERNS = [
  /^\s*at\s+(?<fn>.*?)\s+\((?<url>.*?):(?<line>\d+):(?<column>\d+)\)$/,
  /^\s*at\s+(?<url>.*?):(?<line>\d+):(?<column>\d+)$/,
  /^(?<fn>.*?)@(?<url>.*?):(?<line>\d+):(?<column>\d+)$/,
];

function parseStack(stack) {
  if (!stack) {
    return [];
  }

  const frames = [];

  for (const rawLine of stack.split("\n")) {
    const line = rawLine.trim();
    if (!line || line.startsWith("Error")) {
      continue;
    }

    for (const pattern of STACK_FRAME_PATTERNS) {
      const match = line.match(pattern);
      if (match) {
        frames.push({
          fn: match.groups.fn || null,
          url: match.groups.url,
          line: parseInt(match.groups.line, 10),
          column: parseInt(match.groups.column, 10),
        });
        break;
      }
    }
  }

  return frames;
}

function scriptBasenameFor(url) {
  try {
    return path.basename(new URL(url).pathname);
  } catch {
    return path.basename(url.split(/[?#]/)[0]);
  }
}

function isPlumbing(file) {
  return PLUMBING_PATTERNS.some((pattern) => pattern.test(`/${file}`));
}

function ownFrames(frames) {
  return frames.filter(
    (frame) =>
      frame.resolved &&
      !isPlumbing(frame.file) &&
      !frame.file.includes("node_modules/")
  );
}

class DeprecationStackResolver {
  #index;

  constructor({ mapRoots = MAP_ROOTS } = {}) {
    this.#index = new SourceMapIndex(mapRoots);
  }

  resolveFrame(frame) {
    const sourceMap = this.#index.forScript(scriptBasenameFor(frame.url));
    const original = sourceMap?.originalPositionFor(frame.line, frame.column);

    if (!original) {
      return {
        function: frame.fn,
        file: scriptBasenameFor(frame.url),
        line: frame.line,
        column: frame.column,
        resolved: false,
      };
    }

    return {
      function: frame.fn,
      ...original,
      resolved: true,
    };
  }

  resolveStack(stack, { maxFrames = MAX_RESOLVED_FRAMES } = {}) {
    return parseStack(stack)
      .slice(0, maxFrames)
      .map((frame) => this.resolveFrame(frame));
  }

  resolve(entry) {
    const frames = this.resolveStack(entry.stack);
    const owned = ownFrames(frames);
    const viaWrapper = frames.some(
      (frame) => frame.resolved && DEPRECATION_WRAPPER_PATTERN.test(frame.file)
    );
    const callers = viaWrapper ? owned.slice(1) : owned;
    const site = callers[0] || null;
    const stackTestFrame = callers.find((frame) =>
      TEST_FILE_PATTERN.test(`/${frame.file}`)
    );
    const declaredTestFrame = this.resolveStack(entry.testStack, {
      maxFrames: 20,
    }).find(
      (frame) => frame.resolved && TEST_FILE_PATTERN.test(`/${frame.file}`)
    );
    const suppliedTest = entry.test || {};
    const testFile = suppliedTest.file
      ? normalizeFile(suppliedTest.file)
      : declaredTestFrame?.file || stackTestFrame?.file || null;
    const testLine =
      suppliedTest.callSiteLine ||
      suppliedTest.declarationLine ||
      stackTestFrame?.line ||
      declaredTestFrame?.line ||
      null;

    return {
      id: entry.id,
      count: entry.count || 1,
      origin: entry.origin || "unknown",
      site,
      spec: testFile
        ? `${testFile}${testLine ? `:${testLine}` : ""}`
        : suppliedTest.name || entry.testName || null,
    };
  }
}

function rawEntryKey(entry) {
  return [
    entry.id,
    entry.origin,
    entry.module,
    entry.testName,
    entry.test?.file,
    entry.test?.name,
    entry.stack,
  ].join("\u0000");
}

function mergeRawEntries(entries) {
  const merged = new Map();

  for (const entry of entries) {
    const key = rawEntryKey(entry);
    const existing = merged.get(key);

    if (existing) {
      existing.count += entry.count || 1;
    } else {
      merged.set(key, { ...entry, count: entry.count || 1 });
    }
  }

  return merged.values();
}

function buildReport({
  group,
  entries,
  totals = {},
  totalsByOrigin = {},
  resolver = new DeprecationStackResolver(),
}) {
  const accumulator = new ReportAccumulator();

  for (const entry of mergeRawEntries(entries)) {
    accumulator.addOccurrence(resolver.resolve(entry), group);
  }

  accumulator.reconcileTotals(group, totals, totalsByOrigin);
  return accumulator.toReport();
}

module.exports = {
  DeprecationStackResolver,
  buildReport,
  mergeReports,
  parseStack,
  renderReportSummary,
};
