import valueParser from "postcss-value-parser";
import renames from "../../app/assets/stylesheets/variable-renames.json";

/**
 * Rewrites renamed CSS custom properties to their current names, so
 * stylesheets which set or read an old name keep working. Each rewritten
 * declaration gets a trailing `automatically renamed` comment as a clue in
 * dev-tools.
 */

export default function postcssVariableRenamer(renameMap = renames) {
  const oldNames = Object.keys(renameMap);

  return {
    postcssPlugin: "postcss-variable-renamer",

    Declaration(declaration, { Comment }) {
      const applied = new Map();
      const oldProp = declaration.prop;
      const oldValue = declaration.value;

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
