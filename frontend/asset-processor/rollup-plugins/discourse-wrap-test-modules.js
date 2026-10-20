import MagicString from "magic-string";

// The test entrypoint also lists helpers, which must keep their exports
const TEST_FILE_REGEX = /-test\.(?:gjs|js|ts|gts)$/;

export function testModuleIdsFor(basePath, testModules = []) {
  return new Set(
    testModules
      .filter((path) => TEST_FILE_REGEX.test(path))
      .map((path) => `${basePath}${path}`)
  );
}

// Defers each test file's body to a default-exported function, so the test runner can run
// only the files it selected instead of every test registering on import.
export default function discourseWrapTestModules({ testModuleIds }) {
  return {
    name: "discourse-wrap-test-modules",

    transform: {
      // After the gjs and babel transforms, so this parses plain JS.
      order: "post",

      handler(code, id) {
        if (!testModuleIds.has(id)) {
          return null;
        }

        const { body } = this.parse(code);

        // An export can't move into the wrapper, so the module has to stay as it is
        if (body.some((node) => node.type.startsWith("Export"))) {
          this.warn(
            "A test file with exports can't be wrapped, so its tests always run"
          );
          return null;
        }

        const statementIndex = body.findIndex(
          (node) => node.type !== "ImportDeclaration"
        );
        const leadingImports =
          statementIndex === -1 ? body : body.slice(0, statementIndex);
        const wrapStart = leadingImports.at(-1)?.end ?? 0;
        const magic = new MagicString(code);

        // Imports can't go inside the wrapper either, e.g. the one appended to `.js.es6` files
        for (const node of body.slice(leadingImports.length)) {
          if (node.type === "ImportDeclaration") {
            magic.move(node.start, node.end, wrapStart);
          }
        }

        // `prependRight` keeps the moved imports ahead of the wrapper
        magic.prependRight(wrapStart, "\nexport default function () {\n");
        // App modules can end in "-test" too, so the runner needs a marker to tell them apart
        magic.append("\n}\nexport const __discourseTestModule = true;\n");

        return {
          code: magic.toString(),
          map: magic.generateMap({ hires: true }),
        };
      },
    },
  };
}
