import { REPORT_SCHEMA } from "./analyze.mjs";

const MAX_ITEMS = 2000;
const MAX_STRING = 1000;

/**
 * Rebuilds a report from its known fields, checking each type. The report is
 * produced by untrusted PR code; anything unexpected throws, and unknown
 * fields are dropped.
 */
export function validateReport(input) {
  if (input?.schema !== REPORT_SCHEMA) {
    throw new Error(`Unsupported report schema: ${input?.schema}`);
  }
  if (input.noJsChanges === true) {
    return { schema: REPORT_SCHEMA, noJsChanges: true };
  }
  return shape({
    schema: num,
    noJsChanges: bool,
    initialLoad: shape({
      base: num,
      head: num,
      entryOwn: pair,
      chunks: pair,
      topModules: list(moduleDelta),
    }),
    totals: shape({ base: num, head: num, chunks: pair }),
    bundles: list(
      shape({
        key: str,
        name: str,
        kind: oneOf("entry", "lazy"),
        facade: nullable(str),
        isMain: bool,
        status: oneOf("new", "removed", "same"),
        movedToInitialLoad: bool,
        base: nullable(shape({ own: num, load: num })),
        head: nullable(shape({ own: num, load: num })),
        topModules: list(moduleDelta),
        importedBy: list(
          shape({
            from: str,
            fromName: str,
            kind: edgeKind,
            examples: list(example),
          })
        ),
      })
    ),
    movedIntoInitialLoad: list(
      shape({
        bundle: str,
        name: str,
        bytes: num,
        modules: list(shape({ id: str, bytes: num })),
        importers: list(example),
      })
    ),
    edges: shape({ added: list(edge), removed: list(edge) }),
    assets: list(
      shape({ label: str, base: nullable(num), head: nullable(num) })
    ),
    duplicatePackages: list(
      shape({ name: str, versions: list(str), new: bool })
    ),
  })(input, "report");
}

function edgeKind(value, path) {
  return oneOf("static", "dynamic", "url")(value, path);
}

function example(value, path) {
  return shape({ from: str, to: str })(value, path);
}

function edge(value, path) {
  return shape({
    from: str,
    to: str,
    kind: edgeKind,
    fromName: str,
    toName: str,
    examples: list(example),
  })(value, path);
}

function moduleDelta(value, path) {
  return shape({ id: str, delta: num, added: bool })(value, path);
}

function pair(value, path) {
  return shape({ base: num, head: num })(value, path);
}

function fail(path, expected) {
  throw new Error(`report: ${path} must be ${expected}`);
}

function num(value, path) {
  return Number.isFinite(value) ? value : fail(path, "a number");
}

function bool(value, path) {
  return typeof value === "boolean" ? value : fail(path, "a boolean");
}

function str(value, path) {
  return typeof value === "string" && value.length <= MAX_STRING
    ? value
    : fail(path, `a string of at most ${MAX_STRING} characters`);
}

function oneOf(...allowed) {
  return (value, path) =>
    allowed.includes(value)
      ? value
      : fail(path, `one of ${allowed.join(", ")}`);
}

function nullable(check) {
  return (value, path) => (value === null ? null : check(value, path));
}

function list(check) {
  return (value, path) => {
    if (!Array.isArray(value) || value.length > MAX_ITEMS) {
      fail(path, `an array of at most ${MAX_ITEMS} items`);
    }
    return value.map((item, i) => check(item, `${path}[${i}]`));
  };
}

function shape(fields) {
  return (value, path = "report") => {
    if (!value || typeof value !== "object" || Array.isArray(value)) {
      fail(path, "an object");
    }
    const result = Object.create(null);
    for (const [name, check] of Object.entries(fields)) {
      result[name] = check(value[name], `${path}.${name}`);
    }
    return result;
  };
}
