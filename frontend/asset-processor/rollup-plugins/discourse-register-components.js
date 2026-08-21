import MagicString from "magic-string";

const STORE = "discourse/lib/deferred-class-modifications";
const BINDING = "__discourseComponentClass";

// Anchored to the top-level segment, so `components/chat/routes/channel` is a component but
// `routes/chat/components/thing` is not.
const COMPONENT_REGEX = /^[^/]+\/components\/(.+)$/;

// `discourse/components/chat/header/icon.gjs` is looked up as `component:chat/header/icon`.
function componentPathFor(id, basePath) {
  if (!id.startsWith(basePath)) {
    return null;
  }

  const match = id.slice(basePath.length).match(COMPONENT_REGEX);

  return match
    ? match[1].replace(/\.[^./]+$/, "").replace(/\/index$/, "")
    : null;
}

// Components are reached by import, never registered with `define()`, so nothing can look one up
// by name. Each module says what it is as it evaluates, which is also the point at which a
// `modifyClass` call that arrived first can be applied.
export default function discourseRegisterComponents({ basePath }) {
  return {
    name: "discourse-register-components",

    transform: {
      // After the gjs and babel transforms, so this parses plain JS and sees whatever class
      // they ended up producing.
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
          // An anonymous class, or any other expression, has nothing to pass along.
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
