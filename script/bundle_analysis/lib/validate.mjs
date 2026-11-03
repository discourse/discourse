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
        status: oneOf("new", "removed", "same"),
        base: nullable(shape({ own: num, load: num })),
        head: nullable(shape({ own: num, load: num })),
        topModules: list(moduleDelta),
        importedBy: list(edge),
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

function fail(path, expected) {
  throw new Error(`report: ${path} must be ${expected}`);
}

const is = (test, expected) => (value, path) =>
  test(value) ? value : fail(path, expected);
const num = is(Number.isFinite, "a number");
const bool = is((value) => typeof value === "boolean", "a boolean");
const str = is(
  (value) => typeof value === "string" && value.length <= MAX_STRING,
  `a string of at most ${MAX_STRING} characters`
);
const oneOf = (...allowed) =>
  is((value) => allowed.includes(value), `one of ${allowed.join(", ")}`);

const edgeKind = oneOf("static", "dynamic", "url");
const example = shape({ from: str, to: str });
const edge = shape({
  from: str,
  to: str,
  kind: edgeKind,
  fromName: str,
  toName: str,
  example: nullable(example),
});
const moduleDelta = shape({ id: str, delta: num, added: bool });
const pair = shape({ base: num, head: num });

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
