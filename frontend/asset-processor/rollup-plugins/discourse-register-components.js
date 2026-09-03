import MagicString from "magic-string";
import { stripExtension } from "../rollup-virtual-imports";

const STORE = "discourse/lib/deferred-class-modifications";
const BINDING = "__discourseComponentClass";

// What the resolver's suffix lookup accepts: `components/<name>` at any depth, and never a
// module under `templates/`. `lookupModuleBySuffix` also falls back to `<name>/index`.
const COMPONENT_REGEX = /(^|\/)components\/(.+)$/;
const CLASSIC_TEMPLATE_REGEX = /(^|\/)templates\//;

function componentPathFor(id, basePath) {
  if (!id.startsWith(basePath)) {
    return null;
  }

  const path = id.slice(basePath.length);

  if (CLASSIC_TEMPLATE_REGEX.test(path)) {
    return null;
  }

  const match = path.match(COMPONENT_REGEX);

  return match ? stripExtension(match[2]).replace(/\/index$/, "") : null;
}

// Components are reached by import, so nothing can look one up by name. Each module says what
// it is as it evaluates, which is when a `modifyClass` call that arrived first can be applied.
export default function discourseRegisterComponents({ basePath }) {
  return {
    name: "discourse-register-components",

    transform: {
      // After the gjs and babel transforms, so this parses plain JS.
      order: "post",

      handler(code, id) {
        const path = componentPathFor(id, basePath);

        if (!path) {
          return null;
        }

        const exported = this.parse(code).body.find(
          (node) => node.type === "ExportDefaultDeclaration"
        );

        if (!exported) {
          return null;
        }

        const declaration = exported.declaration;
        const magic = new MagicString(code);

        let binding;

        if (declaration.type === "Identifier") {
          binding = declaration.name;
        } else if (declaration.type === "ClassDeclaration" && declaration.id) {
          binding = declaration.id.name;
        } else {
          // An anonymous class, or any other expression, has no name to pass along.
          binding = BINDING;
          const terminated = code[exported.end - 1] === ";";

          magic.overwrite(
            exported.start,
            declaration.start,
            `const ${binding} = `
          );
          magic.appendLeft(
            exported.end,
            `${terminated ? "" : ";"}\nexport default ${binding};`
          );
        }

        magic.append(
          `\nimport { registerModuleForModifyClass } from "${STORE}";\n` +
            `registerModuleForModifyClass(${JSON.stringify(path)}, ${binding});\n`
        );

        return {
          code: magic.toString(),
          map: magic.generateMap({ hires: true }),
        };
      },
    },
  };
}
