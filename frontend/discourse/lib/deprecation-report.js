"use strict";

// Turns raw browser stack traces collected alongside JS deprecations into
// original source locations, using the sourcemaps emitted next to the built
// bundles. Used by the testem reporter to produce the deprecation report
// artifact.

const fs = require("fs");
const path = require("path");

const REPO_ROOT = path.resolve(__dirname, "..", "..", "..");

// Directories which may contain `*.js.map` files for anything loaded by the
// test page. Missing directories are ignored.
const MAP_ROOTS = [
  path.join(REPO_ROOT, "frontend", "discourse", "dist", "assets", "map"),
  path.join(REPO_ROOT, "app", "assets", "generated"),
];

// Frames belonging to the deprecation machinery itself: they are always on top
// of the stack and never point at the code which needs fixing.
const PLUMBING_PATTERNS = [
  /\/app\/lib\/deprecated\.js$/,
  /\/app\/lib\/source-identifier\.js$/,
  /\/tests\/helpers\/deprecation-counter\.js$/,
  /\/tests\/helpers\/raise-on-deprecation\.js$/,
  /\/ember-source\/.*\/deprecate\.js$/,
  /\/@ember\/debug\//,
];

// A stack going through this wrapper means the innermost owned frame is the
// deprecated API, not the code calling it.
const DEPRECATION_WRAPPER_PATTERN = /(^|\/)app\/lib\/deprecated\.js$/;

const TEST_FILE_PATTERN = /\/(tests|spec)\/.*-test\.(js|gjs|ts|gts)$/;

// Raw frames to resolve per stack, and owned frames to keep in the report.
const MAX_RESOLVED_FRAMES = 60;
const MAX_REPORTED_FRAMES = 15;

const BASE64 =
  "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
const BASE64_LOOKUP = new Map(
  Array.from(BASE64).map((char, index) => [char, index])
);

/**
 * Decodes a sourcemap `mappings` string into one array of segments per
 * generated line. Each segment is `[generatedColumn, sourceIndex, sourceLine,
 * sourceColumn]` (0-based), matching the sourcemap spec's delta encoding.
 *
 * @param {string} mappings
 * @returns {number[][][]}
 */
function decodeMappings(mappings) {
  const lines = [];
  let sourceIndex = 0;
  let sourceLine = 0;
  let sourceColumn = 0;

  for (const rawLine of mappings.split(";")) {
    const segments = [];
    let generatedColumn = 0;

    if (rawLine.length > 0) {
      for (const rawSegment of rawLine.split(",")) {
        const values = decodeVlq(rawSegment);
        if (values.length === 0) {
          continue;
        }

        generatedColumn += values[0];

        if (values.length >= 4) {
          sourceIndex += values[1];
          sourceLine += values[2];
          sourceColumn += values[3];
          segments.push([
            generatedColumn,
            sourceIndex,
            sourceLine,
            sourceColumn,
          ]);
        }
      }
    }

    lines.push(segments);
  }

  return lines;
}

function decodeVlq(segment) {
  /* eslint-disable no-bitwise -- base64 VLQ decoding is inherently bitwise */
  const values = [];
  let value = 0;
  let shift = 0;

  for (const char of segment) {
    const digit = BASE64_LOOKUP.get(char);
    if (digit === undefined) {
      return [];
    }

    value += (digit & 31) << shift;

    if (digit & 32) {
      shift += 5;
    } else {
      const negative = value & 1;
      value >>>= 1;
      values.push(negative ? (value === 0 ? -0x80000000 : -value) : value);
      value = 0;
      shift = 0;
    }
  }
  /* eslint-enable no-bitwise */

  return values;
}

class SourceMap {
  #json;
  #decoded;

  constructor(json, mapPath) {
    this.#json = json;
    this.mapPath = mapPath;
  }

  get #lines() {
    this.#decoded ||= decodeMappings(this.#json.mappings || "");
    return this.#decoded;
  }

  /**
   * @param {number} line 1-based generated line
   * @param {number} column 1-based generated column
   * @returns {?{file: string, line: number, column: number, code: ?string}}
   */
  originalPositionFor(line, column) {
    let segments = this.#lines[line - 1];
    let approximate = false;

    // Blank lines and comments carry no mappings; the nearest preceding mapped
    // line still lands in the right function.
    for (let back = 1; back <= 10 && !segments?.length; back++) {
      segments = this.#lines[line - 1 - back];
      approximate = true;
    }

    if (!segments || segments.length === 0) {
      return null;
    }

    const target = column - 1;
    let match = null;

    // Segments are sorted by generated column; take the last one at or before
    // the target.
    for (const segment of segments) {
      if (segment[0] > target) {
        break;
      }
      match = segment;
    }
    match ||= segments[0];

    const source = this.#json.sources?.[match[1]];
    if (!source) {
      return null;
    }

    return {
      file: this.#normalizeSource(source),
      line: match[2] + 1,
      column: match[3] + 1,
      code: this.#sourceLine(match[1], match[2]),
      approximate,
    };
  }

  #normalizeSource(source) {
    const withoutRoot = this.#json.sourceRoot
      ? path.join(this.#json.sourceRoot, source)
      : source;
    const absolute = path.resolve(path.dirname(this.mapPath), withoutRoot);
    const relative = path.relative(REPO_ROOT, absolute);
    return relative.startsWith("..") ? absolute : relative;
  }

  #sourceLine(sourceIndex, zeroBasedLine) {
    const content = this.#json.sourcesContent?.[sourceIndex];
    if (!content) {
      return null;
    }

    const line = content.split("\n")[zeroBasedLine];
    return line === undefined ? null : line.trim().slice(0, 200);
  }
}

class SourceMapIndex {
  #byBasename = null;
  #cache = new Map();

  #index() {
    if (this.#byBasename) {
      return this.#byBasename;
    }

    this.#byBasename = new Map();
    for (const root of MAP_ROOTS) {
      this.#walk(root);
    }
    return this.#byBasename;
  }

  #walk(dir, depth = 0) {
    if (depth > 6) {
      return;
    }

    let entries;
    try {
      entries = fs.readdirSync(dir, { withFileTypes: true });
    } catch {
      return;
    }

    for (const entry of entries) {
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        this.#walk(full, depth + 1);
      } else if (entry.name.endsWith(".map")) {
        this.#byBasename.set(entry.name, full);
      }
    }
  }

  /**
   * @param {string} scriptBasename e.g. "discourse-abc123.digested.js"
   * @returns {?SourceMap}
   */
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
  // Chrome: "    at fnName (url:line:col)"
  /^\s*at\s+(?<fn>.*?)\s+\((?<url>.*?):(?<line>\d+):(?<column>\d+)\)$/,
  // Chrome: "    at url:line:col"
  /^\s*at\s+(?<url>.*?):(?<line>\d+):(?<column>\d+)$/,
  // Firefox: "fnName@url:line:col"
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

function isVendored(file) {
  return file.includes("node_modules/");
}

function toLocation(frame) {
  return {
    function: frame.function || null,
    file: frame.file,
    line: frame.line,
    column: frame.column,
    code: frame.code || null,
  };
}

/**
 * Frames in code we own: everything the report is actually about. Framework and
 * reporting frames are dropped, since a deprecation raised through a computed
 * property or the runloop buries the interesting frames under dozens of them.
 *
 * @param {Object[]} frames resolved frames, innermost first
 * @returns {Object[]}
 */
function ownFrames(frames) {
  return frames.filter(
    (frame) =>
      frame.resolved && !isPlumbing(frame.file) && !isVendored(frame.file)
  );
}

class DeprecationStackResolver {
  #index = new SourceMapIndex();

  /**
   * Resolves one raw frame to its original source location, falling back to the
   * built asset when no sourcemap is available.
   */
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
      file: original.file,
      line: original.line,
      column: original.column,
      code: original.code,
      resolved: true,
      ...(original.approximate ? { approximate: true } : {}),
    };
  }

  resolveStack(stack, { maxFrames = MAX_RESOLVED_FRAMES } = {}) {
    return parseStack(stack)
      .slice(0, maxFrames)
      .map((frame) => this.resolveFrame(frame));
  }

  /**
   * Expands one collected deprecation occurrence into a report entry with the
   * spec location, the code that must be fixed, and the frames in between.
   *
   * @param {Object} entry as emitted by the browser-side deprecation counter
   * @returns {Object}
   */
  buildEntry(entry) {
    const frames = this.resolveStack(entry.stack);
    const own = ownFrames(frames);

    // With a Discourse `deprecated()` call the innermost owned frame is the
    // deprecated API itself, and its caller is what needs changing. Ember's own
    // deprecations have no such wrapper, so the innermost owned frame is already
    // the caller.
    const viaWrapper = frames.some(
      (frame) => frame.resolved && DEPRECATION_WRAPPER_PATTERN.test(frame.file)
    );
    const deprecatedApi = viaWrapper ? own[0] || null : null;
    const callers = viaWrapper ? own.slice(1) : own;

    const deprecationSite = callers[0] || own[0] || frames[0] || null;
    const specCallSite =
      callers.find((f) => TEST_FILE_PATTERN.test(`/${f.file}`)) || null;
    const specFile = this.resolveStack(entry.testStack, { maxFrames: 1 })[0];

    return {
      id: entry.id,
      count: entry.count,
      origin: entry.origin || null,
      test: {
        module: entry.module || null,
        name: entry.testName || null,
        file: specFile?.file || null,
        // Line where `test(...)` is declared.
        declarationLine: specFile?.line || null,
        // Line inside the test which actually triggered the deprecation.
        callSiteLine: specCallSite?.line || null,
        callSiteCode: specCallSite?.code || null,
        // Callers which already know the spec (e.g. RSpec system specs) pass it
        // through directly rather than recovering it from a JS stack.
        ...entry.test,
      },
      // The code to change: what called the deprecated API.
      deprecationSite: deprecationSite && toLocation(deprecationSite),
      // The deprecated API itself, for context.
      deprecatedApi: deprecatedApi && toLocation(deprecatedApi),
      // Framework and reporting frames are dropped; they are the same for every
      // occurrence and bury the frames that matter.
      stack: callers.slice(0, MAX_REPORTED_FRAMES).map(toLocation),
    };
  }
}

/**
 * Collapses identical occurrences reported by different browsers (or different
 * parallel spec processes) into one entry.
 *
 * @param {Object[]} entries
 * @returns {Object[]}
 */
function mergeEntries(entries) {
  const merged = new Map();

  for (const entry of entries) {
    const key = [
      entry.id,
      entry.origin,
      entry.module,
      entry.testName,
      entry.test?.file,
      entry.test?.name,
      entry.stack,
    ].join(" ");

    const existing = merged.get(key);
    if (existing) {
      existing.count += entry.count || 1;
    } else {
      merged.set(key, { ...entry, count: entry.count || 1 });
    }
  }

  return Array.from(merged.values());
}

/**
 * Builds the full report document written to disk.
 *
 * @param {Object} options
 * @param {string} options.group run group label, e.g. "frontend-core"
 * @param {Object[]} options.entries raw entries collected from the browsers
 * @returns {Object}
 */
function buildReport({ group, entries }) {
  const resolver = new DeprecationStackResolver();
  const deprecations = mergeEntries(entries).map((entry) =>
    resolver.buildEntry(entry)
  );

  const totals = {};
  for (const deprecation of deprecations) {
    totals[deprecation.id] = (totals[deprecation.id] || 0) + deprecation.count;
  }

  deprecations.sort(
    (a, b) =>
      a.id.localeCompare(b.id) ||
      (a.test.file || "").localeCompare(b.test.file || "") ||
      (a.test.callSiteLine || 0) - (b.test.callSiteLine || 0)
  );

  return {
    group,
    generatedAt: new Date().toISOString(),
    totals,
    sites: aggregateSites(deprecations),
    deprecations,
  };
}

// Specs listed per call site before the list is truncated.
const MAX_SITE_SPECS = 10;

/**
 * The work list: every distinct place that calls a deprecated API, ranked by how
 * often it fires, with a sample of the specs which exercise it.
 *
 * @param {Object[]} deprecations
 * @returns {Object[]}
 */
function aggregateSites(deprecations) {
  const sites = new Map();

  for (const deprecation of deprecations) {
    const site = deprecation.deprecationSite;
    if (!site) {
      continue;
    }

    const key = `${deprecation.id} ${site.file}:${site.line}`;
    let entry = sites.get(key);

    if (!entry) {
      entry = {
        id: deprecation.id,
        file: site.file,
        line: site.line,
        code: site.code,
        count: 0,
        specCount: 0,
        specs: [],
      };
      sites.set(key, entry);
    }

    entry.count += deprecation.count;

    const spec = deprecation.test.file
      ? `${deprecation.test.file}${deprecation.test.callSiteLine ? `:${deprecation.test.callSiteLine}` : ""}`
      : deprecation.test.name;

    if (spec && !entry.specs.includes(spec)) {
      entry.specCount++;
      if (entry.specs.length < MAX_SITE_SPECS) {
        entry.specs.push(spec);
      }
    }
  }

  return Array.from(sites.values()).sort((a, b) => b.count - a.count);
}

module.exports = {
  DeprecationStackResolver,
  buildReport,
  parseStack,
  decodeMappings,
};
