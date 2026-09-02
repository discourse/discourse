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

postcssVariableRenamer.postcss = true;
