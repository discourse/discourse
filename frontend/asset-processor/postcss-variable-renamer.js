import valueParser from "postcss-value-parser";
import borderSplits from "../../app/assets/stylesheets/variable-border-splits.json";
import renames from "../../app/assets/stylesheets/variable-renames.json";
import {
  splitBorderReads,
  splitBorderSetter,
} from "./border-shorthand-splitter.mjs";

/**
 * Rewrites renamed CSS custom properties to their current names, so
 * stylesheets which set or read an old name keep working. Variables that held a
 * whole `border` shorthand are split into their width and color variables.
 * Each rewritten declaration gets a trailing `automatically renamed` or
 * `automatically split` comment as a clue in dev-tools.
 */

export default function postcssVariableRenamer(
  renameMap = renames,
  splitMap = borderSplits
) {
  const oldNames = Object.keys(renameMap);

  return {
    postcssPlugin: "postcss-variable-renamer",

    Declaration(declaration, { Comment }) {
      if (Object.hasOwn(splitMap, declaration.prop)) {
        const split = splitBorderSetter(
          declaration.prop,
          declaration.value,
          splitMap
        );
        if (split) {
          for (const { prop, value } of split.declarations) {
            declaration.cloneBefore({ prop, value });
          }
          const lost = split.lost.length
            ? `, without its ${split.lost.join(" and ")}`
            : "";
          declaration.replaceWith(
            new Comment({
              text: `automatically split ${declaration.prop}: ${declaration.value}${lost}`,
            })
          );
          return;
        }
      }

      const applied = new Map();
      const oldProp = declaration.prop;
      const oldValue = declaration.value;

      const reads = splitBorderReads(declaration.value, splitMap);
      for (const name of reads.names) {
        const { width, color } = splitMap[name];
        applied.set(name, `${width} and ${color}`);
      }
      declaration.value = reads.value;

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

      // When two old names merge into one, setting one from the other (`--a:
      // var(--b)`) becomes a reference to itself, which would make the
      // variable invalid. The merge already makes them equal, so drop it.
      if (
        applied.size > 0 &&
        isSelfReference(declaration.prop, declaration.value) &&
        !isSelfReference(oldProp, oldValue)
      ) {
        declaration.replaceWith(
          new Comment({
            text: `automatically removed ${oldProp}: ${oldValue}, both names now refer to ${declaration.prop}`,
          })
        );
        return;
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

function isSelfReference(prop, value) {
  const nodes = valueParser(value).nodes.filter(
    (node) => node.type !== "space"
  );
  return (
    nodes.length === 1 &&
    nodes[0].type === "function" &&
    nodes[0].value === "var" &&
    nodes[0].nodes[0]?.value === prop
  );
}

postcssVariableRenamer.postcss = true;
