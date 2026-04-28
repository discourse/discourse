import MagicString from "magic-string";

const TEST_FILE_RE = /tests\/(?!helpers\/).*-test\.(?:gjs|js)$/;

export default function wrapTestModulesPlugin() {
  return {
    name: "wrap-test-modules",
    transform: {
      filter: { id: TEST_FILE_RE },
      handler(code, id) {
        if (!TEST_FILE_RE.test(id)) {
          return null;
        }

        const ast = this.parse(code);

        let lastImportEnd = 0;
        for (const node of ast.body) {
          if (node.type === "ImportDeclaration") {
            lastImportEnd = node.end;
          }
        }

        if (lastImportEnd >= code.length) {
          return null;
        }

        const s = new MagicString(code);
        s.appendLeft(lastImportEnd, "\n\nexport default function () {\n");
        s.append("\n}\n");

        return {
          code: s.toString(),
          map: s.generateMap({ hires: "boundary" }),
        };
      },
    },
  };
}
