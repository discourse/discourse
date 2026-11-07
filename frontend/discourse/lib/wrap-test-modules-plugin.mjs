const TEST_FILE_RE = /tests\/(?!helpers\/).*-test\.(?:gjs|js|ts|gts)$/;

export default function wrapTestModulesPlugin() {
  return {
    name: "wrap-test-modules",
    transform: {
      filter: { id: TEST_FILE_RE },
      handler(code, id, { ast, magicString }) {
        const imports = [];
        for (const node of ast.body) {
          if (node.type === "ImportDeclaration") {
            imports.push(code.slice(node.start, node.end));
            magicString.remove(node.start, node.end);
          }
        }

        magicString.prepend(
          `${imports.join("\n")}\n\nexport default function () {\n`
        );
        magicString.append("\n}\n");

        return {
          code: magicString,
        };
      },
    },
  };
}
