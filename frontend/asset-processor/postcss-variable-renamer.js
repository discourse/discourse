import valueParser from "postcss-value-parser";
import renames from "../../app/assets/stylesheets/variable-renames.json";
import rgbTwins from "../../app/assets/stylesheets/variable-rgb-twins.json";

/**
 * Rewrites renamed CSS custom properties to their current names, so
 * stylesheets which set or read an old name keep working. Each rewritten
 * declaration gets a trailing `automatically renamed` comment as a clue in
 * dev-tools.
 *
 * Removed `-rgb` twins are read through `rgb()`, so those calls are rewritten
 * to `color-mix()` on the full color instead.
 */

export default function postcssVariableRenamer(
  renameMap = renames,
  twinMap = rgbTwins
) {
  const oldNames = Object.keys(renameMap);
  const twinNames = Object.keys(twinMap);

  return {
    postcssPlugin: "postcss-variable-renamer",

    Declaration(declaration, { Comment }) {
      const applied = new Map();

      if (twinNames.some((twin) => declaration.value.includes(twin))) {
        const rewritten = rewriteTwins(declaration.value, twinMap);
        if (rewritten.twins.size > 0) {
          declaration.value = rewritten.value;
          const details = [...rewritten.twins]
            .map(([twin, color]) => `${twin} to color-mix() on ${color}`)
            .join(", ");
          declaration.after(
            new Comment({ text: `automatically rewrote ${details}` })
          );
        }
      }

      const newProp = renameMap[declaration.prop];
      if (newProp) {
        applied.set(declaration.prop, newProp);
        declaration.prop = newProp;
      }

      if (oldNames.some((oldName) => declaration.value.includes(oldName))) {
        let valueChanged = false;
        const parsed = valueParser(declaration.value);

        parsed.walk((node) => {
          const newName = node.type === "word" && renameMap[node.value];
          if (newName) {
            applied.set(node.value, newName);
            node.value = newName;
            valueChanged = true;
          }
        });

        if (valueChanged) {
          declaration.value = parsed.toString();
        }
      }

      if (applied.size > 0) {
        const details = [...applied]
          .map(([oldName, newName]) => `${oldName} to ${newName}`)
          .join(", ");
        declaration.after(
          new Comment({ text: `automatically renamed ${details}` })
        );
      }
    },
  };
}

function rewriteTwins(value, twinMap) {
  const twins = new Map();
  const parsed = valueParser(value);

  parsed.walk((node) => {
    if (node.type !== "function" || !/^rgba?$/i.test(node.value)) {
      return;
    }

    const [first, ...rest] = node.nodes.filter((n) => n.type !== "space");
    const twin =
      first?.type === "function" &&
      first.value === "var" &&
      first.nodes[0]?.value;
    const color = twin && first.nodes.length === 1 && twinMap[twin];
    if (!color) {
      return;
    }

    let replacement;
    if (rest.length === 0) {
      replacement = `var(${color})`;
    } else if (
      rest.length === 2 &&
      rest[0].type === "div" &&
      [",", "/"].includes(rest[0].value)
    ) {
      const alpha = valueParser.stringify(rest[1]);
      replacement = `color-mix(in srgb, var(${color}) ${alphaToPercent(alpha)}, transparent)`;
    } else {
      return;
    }

    twins.set(twin, color);
    node.type = "word";
    node.value = replacement;
    delete node.nodes;
    return false;
  });

  return { value: parsed.toString(), twins };
}

function alphaToPercent(alpha) {
  if (alpha.endsWith("%")) {
    return alpha;
  }
  if (/^\d*\.?\d+$/.test(alpha)) {
    return `${Math.round(parseFloat(alpha) * 10000) / 100}%`;
  }
  return `calc(${alpha} * 100%)`;
}

postcssVariableRenamer.postcss = true;
