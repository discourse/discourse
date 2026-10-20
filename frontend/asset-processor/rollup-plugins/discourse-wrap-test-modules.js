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

        if (body.some((node) => node.type.startsWith("Export"))) {
          this.warn(
            "A test file with exports can't be wrapped, so its tests always run"
          );
          return null;
        }

        const magic = new MagicString(code);
        let wrapStart = 0;
        let inBody = false;

        for (const node of body) {
          if (node.type !== "ImportDeclaration") {
            inBody = true;
          } else if (inBody) {
            // Imports can't go inside the wrapper, e.g. the one appended to `.js.es6` files
            magic.move(node.start, node.end, wrapStart);
          } else {
            wrapStart = node.end;
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
