/**
 * Wraps each test module's body in a default-exported function.
 *
 * @param {object} options
 * @param {string} options.root - absolute path of the build root. Only its own
 *   `tests` directory counts, since a `tests/` higher up the checkout's path is
 *   not a test directory.
 */
export default function wrapTestModulesPlugin({ root }) {
  const escapedRoot = root.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const testModule = new RegExp(
    `^${escapedRoot}/tests/(?!helpers/).*-test\\.(?:gjs|js|ts|gts)$`
  );

  return {
    name: "wrap-test-modules",
    transform: {
      filter: { id: testModule },
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
