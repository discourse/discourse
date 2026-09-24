#!/usr/bin/env node

import { readFileSync, statSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { parseArgs } from "node:util";

const DEFAULT_BUILD = fileURLToPath(
  new URL("../frontend/discourse/dist", import.meta.url)
);

export function readReport(input = DEFAULT_BUILD) {
  if (statSync(input).isDirectory()) {
    const manifest = JSON.parse(
      readFileSync(path.join(input, "manifest/manifest.json"), "utf8")
    );
    if (!manifest.bundleAnalysis) {
      throw new Error(`No bundleAnalysis in ${input}/manifest/manifest.json`);
    }
    input = path.join(input, manifest.bundleAnalysis);
  }
  const report = JSON.parse(readFileSync(input, "utf8"));
  if (!Array.isArray(report.entrypoints) || !report.chunks) {
    throw new Error(`${input} is not a core bundle analysis report`);
  }
  return report;
}

// Follow only static edges. A Set handles both shared dependencies and cycles.
export function summarize(report, entryName) {
  const entries = [
    ...new Set([...report.entrypoints, ...(report.dynamicEntrypoints ?? [])]),
  ].map((file) => {
    const chunk = report.chunks[file];
    if (!chunk?.name) {
      throw new Error(`Missing entrypoint: ${file}`);
    }
    return {
      name: chunk.name === "chunk" ? file : chunk.name,
      file,
      kind: report.entrypoints.includes(file) ? "entry" : "dynamic",
    };
  });
  const selected = entryName
    ? entries.filter(
        ({ name, file }) => name === entryName || file === entryName
      )
    : entries;
  if (!selected.length) {
    throw new Error(`Entrypoint not found: ${entryName || "(none)"}`);
  }
  if (entryName && selected.length > 1) {
    throw new Error(
      "Ambiguous entrypoint name; select its full chunk filename"
    );
  }

  return selected.map(({ name, file, kind }) => {
    const files = new Set();
    const visit = (current) => {
      if (files.has(current)) {
        return;
      }
      const chunk = report.chunks[current];
      if (!chunk) {
        throw new Error(`Missing chunk in static dependency graph: ${current}`);
      }
      files.add(current);
      for (const dependency of chunk.imports) {
        visit(dependency);
      }
    };
    visit(file);

    let rawSize = 0;
    let brotliSize = 0;
    let brotliReady = true;
    const modules = new Map();
    for (const current of files) {
      const chunk = report.chunks[current];
      for (const metric of ["rawSize", "brotliSize"]) {
        const value = chunk[metric];
        if (metric === "brotliSize" && value == null) {
          brotliReady = false;
        } else if (!Number.isSafeInteger(value) || value < 0) {
          throw new Error(`Invalid ${metric} for ${current}`);
        }
      }
      rawSize += chunk.rawSize;
      brotliSize += chunk.brotliSize ?? 0;
      for (const module of chunk.modules) {
        modules.set(
          module.id,
          (modules.get(module.id) ?? 0) + module.renderedLength
        );
      }
    }
    return {
      name,
      file,
      kind,
      chunks: files.size,
      rawSize,
      brotliSize: brotliReady ? brotliSize : null,
      modules: [...modules]
        .map(([id, renderedLength]) => ({ id, renderedLength }))
        .sort(
          (a, b) =>
            b.renderedLength - a.renderedLength || a.id.localeCompare(b.id)
        ),
    };
  });
}

export function compare(
  base,
  head,
  { entry = "discourse", percent = 10, bytes = 25600 } = {}
) {
  if (base.emberEnv !== "production" || head.emberEnv !== "production") {
    throw new Error(
      "Comparison requires two production reports (EMBER_ENV=production)"
    );
  }
  for (const value of [percent, bytes]) {
    if (!Number.isFinite(value) || value < 0) {
      throw new Error("Thresholds must be finite, non-negative numbers");
    }
  }
  const before = summarize(base, entry)[0];
  const after = summarize(head, entry)[0];
  if (before.brotliSize === null || after.brotliSize === null) {
    throw new Error(
      "Comparison requires Brotli sizes for every static dependency"
    );
  }
  const delta = after.brotliSize - before.brotliSize;
  const percentChange =
    before.brotliSize === 0
      ? delta === 0
        ? 0
        : null
      : (delta / before.brotliSize) * 100;
  const beforeModules = new Map(
    before.modules.map((m) => [m.id, m.renderedLength])
  );
  const afterModules = new Map(
    after.modules.map((m) => [m.id, m.renderedLength])
  );
  const moduleChanges = [
    ...new Set([...beforeModules.keys(), ...afterModules.keys()]),
  ]
    .map((id) => ({
      id,
      change: (afterModules.get(id) ?? 0) - (beforeModules.get(id) ?? 0),
      status: !beforeModules.has(id)
        ? "added"
        : !afterModules.has(id)
          ? "removed"
          : "changed",
    }))
    .filter((m) => m.change !== 0)
    .sort(
      (a, b) =>
        Math.abs(b.change) - Math.abs(a.change) || a.id.localeCompare(b.id)
    );
  return {
    entry,
    before: {
      rawSize: before.rawSize,
      brotliSize: before.brotliSize,
      chunks: before.chunks,
    },
    after: {
      rawSize: after.rawSize,
      brotliSize: after.brotliSize,
      chunks: after.chunks,
    },
    delta,
    percentChange,
    thresholds: { percent, bytes },
    // Equality hits the threshold; an unchanged bundle always passes.
    failed:
      delta > 0 &&
      delta >= bytes &&
      delta >= (before.brotliSize * percent) / 100,
    moduleChanges,
  };
}

const HELP = `Usage:
  node script/bundle-analysis.mjs summary [dist-directory|report.json] [--entry NAME] [--json] [--top N]
  node script/bundle-analysis.mjs diff BASE HEAD [--entry NAME] [--percent N] [--bytes N] [--json] [--top N]

Summary defaults to frontend/discourse/dist. Sizes include each entrypoint's
static dependencies, counted once. Module lengths are attribution estimates.
Diff defaults to discourse and fails when Brotli growth reaches BOTH 10% and
25600 bytes (25 KiB). Reports must be production builds with Brotli sizes.
Exit codes: 0 success, 1 size regression, 2 invalid input/build report.
`;

function main() {
  const { values, positionals } = parseArgs({
    allowPositionals: true,
    options: {
      entry: { type: "string" },
      percent: { type: "string", default: "10" },
      bytes: { type: "string", default: "25600" },
      top: { type: "string", default: "20" },
      json: { type: "boolean" },
      help: { type: "boolean", short: "h" },
    },
  });
  if (values.help) {
    console.log(HELP);
    return;
  }
  const top = Number(values.top);
  if (!Number.isSafeInteger(top) || top < 0) {
    throw new Error("--top must be a non-negative integer");
  }
  const [command, ...inputs] = positionals;
  if (command === "summary" && inputs.length <= 1) {
    const report = readReport(inputs[0]);
    const result = {
      emberEnv: report.emberEnv,
      entries: summarize(report, values.entry),
    };
    if (values.json) {
      console.log(JSON.stringify(result, null, 2));
    } else {
      console.log(
        `Environment: ${result.emberEnv}; static dependency totals (bytes)`
      );
      for (const entry of result.entries) {
        console.log(
          `\n${entry.name}: ${entry.brotliSize ?? "unavailable"} Brotli, ${entry.rawSize} raw, ${entry.chunks} chunks`
        );
        for (const module of entry.modules.slice(0, top)) {
          console.log(`  ${module.renderedLength}\t${module.id}`);
        }
      }
    }
  } else if (command === "diff" && inputs.length === 2) {
    const result = compare(readReport(inputs[0]), readReport(inputs[1]), {
      entry: values.entry,
      percent: Number(values.percent),
      bytes: Number(values.bytes),
    });
    if (values.json) {
      console.log(JSON.stringify(result, null, 2));
    } else {
      console.log(
        `${result.failed ? "FAIL" : "PASS"}: ${result.entry} static dependency total`
      );
      console.log(
        `Brotli: ${result.before.brotliSize} -> ${result.after.brotliSize} bytes (${result.delta >= 0 ? "+" : ""}${result.delta}, ${result.percentChange === null ? "new from zero" : `${result.percentChange.toFixed(2)}%`})`
      );
      console.log(
        `Raw: ${result.before.rawSize} -> ${result.after.rawSize} bytes`
      );
      console.log(
        `Fails at growth >= ${result.thresholds.percent}% AND >= ${result.thresholds.bytes} bytes.`
      );
      console.log(
        "Largest module changes (rendered lengths, not compressed bytes):"
      );
      for (const module of result.moduleChanges.slice(0, top)) {
        console.log(
          `  ${module.change >= 0 ? "+" : ""}${module.change}\t${module.status}\t${module.id}`
        );
      }
    }
    process.exitCode = result.failed ? 1 : 0;
  } else {
    throw new Error(HELP);
  }
}

if (
  process.argv[1] &&
  path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  try {
    main();
  } catch (error) {
    console.error(error.message);
    process.exitCode = 2;
  }
}
