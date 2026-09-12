"use strict";

const FORMAT_VERSION = 1;
const MAX_SITE_SPECS = 10;

function increment(map, key, count) {
  map.set(key, (map.get(key) || 0) + count);
}

function newAggregate({ id, file = null, line = null, code = null }) {
  return {
    id,
    file,
    line,
    code,
    count: 0,
    origins: new Map(),
    groups: new Set(),
    specs: new Set(),
    specCount: 0,
  };
}

function addOccurrence(aggregate, occurrence, group) {
  aggregate.count += occurrence.count;
  increment(aggregate.origins, occurrence.origin, occurrence.count);
  aggregate.groups.add(group);

  if (occurrence.spec && !aggregate.specs.has(occurrence.spec)) {
    aggregate.specs.add(occurrence.spec);
    aggregate.specCount++;
  }
}

function addSerializedAggregate(aggregate, serialized) {
  aggregate.count += serialized.count || 0;
  for (const [origin, count] of Object.entries(serialized.origins || {})) {
    increment(aggregate.origins, origin, count);
  }
  for (const group of serialized.groups || []) {
    aggregate.groups.add(group);
  }
  for (const spec of serialized.specs || []) {
    aggregate.specs.add(spec);
  }
  aggregate.specCount += serialized.specCount || serialized.specs?.length || 0;
}

function serializeAggregate(aggregate) {
  const result = {
    id: aggregate.id,
    count: aggregate.count,
    origins: Object.fromEntries(
      Array.from(aggregate.origins.entries()).sort(([left], [right]) =>
        left.localeCompare(right)
      )
    ),
    groups: Array.from(aggregate.groups).sort(),
    specCount: Math.max(aggregate.specCount, aggregate.specs.size),
    specs: Array.from(aggregate.specs).sort().slice(0, MAX_SITE_SPECS),
  };

  if (aggregate.line !== null) {
    result.line = aggregate.line;
  }
  if (aggregate.code) {
    result.code = aggregate.code;
  }

  return result;
}

class ReportAccumulator {
  #sites = new Map();
  #unresolved = new Map();

  addOccurrence(occurrence, group) {
    if (!occurrence.site) {
      this.#addUnresolved(occurrence, group);
      return;
    }

    const { file, line, code } = occurrence.site;
    const key = `${file}\u0000${occurrence.id}\u0000${line}`;
    let aggregate = this.#sites.get(key);
    if (!aggregate) {
      aggregate = newAggregate({ id: occurrence.id, file, line, code });
      this.#sites.set(key, aggregate);
    }
    addOccurrence(aggregate, occurrence, group);
  }

  reconcileTotals(group, totals, totalsByOrigin) {
    const accountedById = new Map();
    const accountedByOrigin = new Map();

    for (const aggregate of [
      ...this.#sites.values(),
      ...this.#unresolved.values(),
    ]) {
      increment(accountedById, aggregate.id, aggregate.count);
      for (const [origin, count] of aggregate.origins) {
        increment(accountedByOrigin, `${origin}\u0000${aggregate.id}`, count);
      }
    }

    for (const [origin, originTotals] of Object.entries(totalsByOrigin || {})) {
      for (const [id, total] of Object.entries(originTotals)) {
        const missing =
          total - (accountedByOrigin.get(`${origin}\u0000${id}`) || 0);
        if (missing > 0) {
          this.#addUnresolved(
            { id, count: missing, origin, spec: null },
            group
          );
          increment(accountedById, id, missing);
        }
      }
    }

    for (const [id, total] of Object.entries(totals || {})) {
      const missing = total - (accountedById.get(id) || 0);
      if (missing > 0) {
        this.#addUnresolved(
          { id, count: missing, origin: "unknown", spec: null },
          group
        );
      }
    }
  }

  addReport(report) {
    validateReport(report);

    for (const fileEntry of report.files) {
      for (const deprecation of fileEntry.deprecations) {
        const key = `${fileEntry.file}\u0000${deprecation.id}\u0000${deprecation.line}`;
        let aggregate = this.#sites.get(key);
        if (!aggregate) {
          aggregate = newAggregate({
            id: deprecation.id,
            file: fileEntry.file,
            line: deprecation.line,
            code: deprecation.code,
          });
          this.#sites.set(key, aggregate);
        }
        addSerializedAggregate(aggregate, deprecation);
      }
    }

    for (const deprecation of report.unresolved || []) {
      let aggregate = this.#unresolved.get(deprecation.id);
      if (!aggregate) {
        aggregate = newAggregate({ id: deprecation.id });
        this.#unresolved.set(deprecation.id, aggregate);
      }
      addSerializedAggregate(aggregate, deprecation);
    }
  }

  toReport() {
    const byFile = new Map();

    for (const site of this.#sites.values()) {
      if (!byFile.has(site.file)) {
        byFile.set(site.file, []);
      }
      byFile.get(site.file).push(serializeAggregate(site));
    }

    const files = Array.from(byFile, ([file, deprecations]) => ({
      file,
      deprecations: deprecations.sort(
        (left, right) =>
          (left.line || 0) - (right.line || 0) ||
          left.id.localeCompare(right.id)
      ),
    })).sort((left, right) => left.file.localeCompare(right.file));

    return {
      format: FORMAT_VERSION,
      files,
      unresolved: Array.from(
        this.#unresolved.values(),
        serializeAggregate
      ).sort((left, right) => left.id.localeCompare(right.id)),
    };
  }

  #addUnresolved(occurrence, group) {
    let aggregate = this.#unresolved.get(occurrence.id);
    if (!aggregate) {
      aggregate = newAggregate({ id: occurrence.id });
      this.#unresolved.set(occurrence.id, aggregate);
    }
    addOccurrence(aggregate, occurrence, group);
  }
}

function validateReport(report) {
  if (report?.format !== FORMAT_VERSION || !Array.isArray(report.files)) {
    throw new Error("Unsupported deprecation report format");
  }
}

function mergeReports(reports) {
  const accumulator = new ReportAccumulator();
  for (const report of reports) {
    accumulator.addReport(report);
  }
  return accumulator.toReport();
}

function reportTotals(report) {
  const totals = new Map();
  const origins = new Map();
  const all = [
    ...report.files.flatMap((entry) => entry.deprecations),
    ...(report.unresolved || []),
  ];

  for (const deprecation of all) {
    increment(totals, deprecation.id, deprecation.count);
    for (const [origin, count] of Object.entries(deprecation.origins || {})) {
      increment(origins, `${origin}\u0000${deprecation.id}`, count);
    }
  }

  return { totals, origins };
}

function markdownTable(headers, rows) {
  const escape = (value) => String(value).replaceAll("|", "\\|");
  let output = `| ${headers.map(escape).join(" | ")} |\n`;
  output += `| ${headers.map(() => "---").join(" | ")} |\n`;
  for (const row of rows) {
    output += `| ${row.map(escape).join(" | ")} |\n`;
  }
  return output;
}

function renderReportSummary(
  report,
  { detailLimit = 25, reportLocation } = {}
) {
  validateReport(report);
  const { totals, origins } = reportTotals(report);

  if (totals.size === 0) {
    return "### JS deprecations\n\nNo deprecations logged.\n";
  }

  let output =
    "### ⚠️ JS deprecations\n\nTest run completed with deprecations:\n\n";
  output += markdownTable(
    ["id", "count"],
    Array.from(totals.entries())
      .sort(([left], [right]) => left.localeCompare(right))
      .map(([id, count]) => [id, count])
  );

  if (origins.size > 0) {
    output += "\nDeprecations by test origin:\n\n";
    output += markdownTable(
      ["origin", "id", "count"],
      Array.from(origins.entries())
        .map(([key, count]) => [...key.split("\u0000"), count])
        .sort(
          ([leftOrigin, leftId], [rightOrigin, rightId]) =>
            leftOrigin.localeCompare(rightOrigin) ||
            leftId.localeCompare(rightId)
        )
    );
  }

  const sites = report.files
    .flatMap(({ file, deprecations }) =>
      deprecations.map((deprecation) => ({ file, ...deprecation }))
    )
    .sort(
      (left, right) =>
        right.count - left.count ||
        left.file.localeCompare(right.file) ||
        left.line - right.line
    );

  if (sites.length > 0) {
    output += `\nTop ${Math.min(detailLimit, sites.length)} deprecated call sites:\n\n`;
    output += markdownTable(
      ["id", "call site", "count", "specs"],
      sites
        .slice(0, detailLimit)
        .map(({ id, file, line, count, specCount }) => [
          id,
          `${file}:${line}`,
          count,
          specCount,
        ])
    );
  }

  if (report.unresolved?.length > 0) {
    output += "\nUnresolved deprecations:\n\n";
    output += markdownTable(
      ["id", "count"],
      report.unresolved.map(({ id, count }) => [id, count])
    );
  }

  if (reportLocation) {
    output += `\nFull report: ${reportLocation}\n`;
  }

  return output;
}

module.exports = {
  ReportAccumulator,
  mergeReports,
  renderReportSummary,
};
