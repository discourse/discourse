const TEST_FILE_RE = /tests\/(?!helpers\/).*-test\.(?:gjs|js|ts|gts)$/;

export default function wrapTestModulesPlugin() {
  return {
    name: "wrap-test-modules",
    transform: {
      filter: { id: TEST_FILE_RE },
      handler(code, id, { ast, magicString }) {
        let lastImportEnd = 0;
        for (const node of ast.body) {
          if (node.type === "ImportDeclaration") {
            lastImportEnd = node.end;
          }
        }

        if (lastImportEnd >= code.length) {
          return null;
        }

        magicString.appendLeft(
          lastImportEnd,
          "\n\nexport default function () {\n"
        );
        magicString.append("\n}\n");

        return {
          code: magicString,
        };
      },
    },
  };
}
