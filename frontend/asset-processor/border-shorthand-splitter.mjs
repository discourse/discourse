import valueParser from "postcss-value-parser";

const STYLES = new Set([
  "none",
  "hidden",
  "dotted",
  "dashed",
  "solid",
  "double",
  "groove",
  "ridge",
  "inset",
  "outset",
]);
const WIDTHS = new Set(["thin", "medium", "thick"]);
const MATH = new Set(["calc", "min", "max", "clamp"]);

/**
 * Rewrites reads of variables that held a whole `border` shorthand, such as
 * `var(--d-button-border)`, to the width and color variables they were split
 * into: `var(--width) solid var(--color)`.
 *
 * `splits` maps each old name to `{ width, color, style }`.
 */
export function splitBorderReads(value, splits) {
  if (!Object.keys(splits).some((name) => value.includes(name))) {
    return { value, names: [] };
  }

  const parsed = valueParser(value);
  const names = [];
  parsed.walk((node) => {
    if (node.type !== "function" || node.value !== "var") {
      return;
    }
    const name = node.nodes[0]?.value;
    if (!Object.hasOwn(splits, name)) {
      return;
    }

    const { width, color, style = "solid" } = splits[name];
    const comma = node.nodes.findIndex(
      (n) => n.type === "div" && n.value === ","
    );
    const fallback =
      comma === -1 ? {} : parts(withoutSpaces(node.nodes.slice(comma + 1)));
    const withFallback = (variable, part) =>
      part ? `var(${variable}, ${part})` : `var(${variable})`;

    node.type = "word";
    node.value = `${withFallback(width, fallback.width)} ${style} ${withFallback(color, fallback.color)}`;
    names.push(name);
    return false;
  });

  return { value: names.length ? parsed.toString() : value, names };
}

/**
 * Splits a declaration that sets one of those variables into declarations of
 * its width and color variables. Returns null when the value cannot be split,
 * such as a variable this does not know.
 *
 * `lost` lists the parts that the new variables cannot hold, such as a style
 * other than the split's style.
 */
export function splitBorderSetter(prop, value, splits) {
  const { width, color, style = "solid" } = splits[prop];
  const nodes = withoutSpaces(valueParser(value).nodes);

  if (
    nodes.length === 1 &&
    nodes[0].type === "function" &&
    nodes[0].value === "var"
  ) {
    const other = splits[nodes[0].nodes[0]?.value];
    return other
      ? {
          declarations: [{ prop: color, value: `var(${other.color})` }],
          lost: [],
        }
      : null;
  }

  const found = parts(nodes);
  if (found.unknown) {
    return null;
  }
  // Without a style, or with a zero width, a border shorthand draws nothing
  if (
    !found.style ||
    found.style === "none" ||
    found.style === "hidden" ||
    Number.parseFloat(found.width) === 0
  ) {
    return { declarations: [{ prop: width, value: "0" }], lost: [] };
  }

  return {
    declarations: [
      { prop: width, value: found.width ?? "medium" },
      { prop: color, value: found.color ?? "currentcolor" },
    ],
    lost: found.style && found.style !== style ? [`style ${found.style}`] : [],
  };
}

function parts(nodes) {
  const found = {};
  for (const node of nodes) {
    const text = valueParser.stringify(node);
    const number = node.type === "word" && valueParser.unit(node.value);
    if (
      (number && (number.unit || Number(number.number) === 0)) ||
      WIDTHS.has(text) ||
      (node.type === "function" && MATH.has(node.value))
    ) {
      found.width = text;
    } else if (STYLES.has(text)) {
      found.style = text;
    } else if (found.color) {
      found.unknown = true;
    } else {
      found.color = text;
    }
  }
  return found;
}

function withoutSpaces(nodes) {
  return nodes.filter((node) => node.type !== "space");
}
