import valueParser from "postcss-value-parser";

/**
 * Rewrites `rgb()` and `rgba()` reads of deprecated `-rgb` twins, such as
 * `rgb(var(--primary-rgb), 0.5)`, to `color-mix()` on the color variable.
 *
 * Returns the new value, the twins it rewrote, and the twins it could not
 * rewrite, such as reads with a fallback or with an SCSS variable as alpha.
 */
export default function rewriteRgbTwins(value, twins) {
  const parsed = valueParser(value);
  const rewritten = [];
  const remaining = [];

  parsed.walk((node) => {
    if (node.type === "function" && /^rgba?$/i.test(node.value)) {
      const replacement = replacementFor(node, twins);
      if (replacement) {
        rewritten.push(replacement.twin);
        node.type = "word";
        node.value = replacement.value;
        return false;
      }
    }
    if (node.type === "word" && Object.hasOwn(twins, node.value)) {
      remaining.push(node.value);
    }
  });

  return {
    value: rewritten.length ? parsed.toString() : value,
    rewritten,
    remaining,
  };
}

function replacementFor(node, twins) {
  const [first, comma, alpha, ...rest] = withoutSpaces(node.nodes);
  if (first?.type !== "function" || first.value !== "var") {
    return;
  }

  const [name, ...fallback] = withoutSpaces(first.nodes);
  if (!name || !Object.hasOwn(twins, name.value) || fallback.length) {
    return;
  }

  const twin = name.value;
  const color = `var(${twins[twin]})`;
  if (!comma) {
    return { twin, value: color };
  }
  if (comma.type !== "div" || comma.value !== "," || !alpha || rest.length) {
    return;
  }

  const percent = toPercent(alpha);
  if (!percent) {
    return;
  }
  if (percent === "100%") {
    return { twin, value: color };
  }
  return {
    twin,
    value: `color-mix(in srgb, ${color} ${percent}, transparent)`,
  };
}

function toPercent(node) {
  if (node.type === "function" && node.value === "var") {
    return `calc(${valueParser.stringify(node)} * 100%)`;
  }
  if (node.type !== "word") {
    return;
  }

  const number = valueParser.unit(node.value);
  if (!number || !/^\d*\.?\d+$/.test(number.number)) {
    return;
  }
  if (number.unit === "%") {
    return node.value;
  }
  if (number.unit === "") {
    return `${Number((Number(number.number) * 100).toFixed(2))}%`;
  }
}

function withoutSpaces(nodes) {
  return nodes.filter((node) => node.type !== "space");
}
