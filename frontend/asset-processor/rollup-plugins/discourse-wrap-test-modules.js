import MagicString from "magic-string";

// The test entrypoint also lists helpers, which must keep their exports
const TEST_FILE_REGEX = /-test\.(?:gjs|js|ts|gts)$/;

// Defers each test file's body to a default-exported function, so the test runner can run
// only the files it selected instead of every test registering on import.
export default function discourseWrapTestModules({
  basePath,
  testModules = [],
}) {
  const ids = new Set(
    testModules
      .filter((path) => TEST_FILE_REGEX.test(path))
      .map((path) => `${basePath}${path}`)
  );

  return {
    name: "discourse-wrap-test-modules",

    transform: {
      // After the gjs and babel transforms, so this parses plain JS.
      order: "post",

      handler(code, id) {
        if (!ids.has(id)) {
          return null;
        }

        const lastImport = this.parse(code)
          .body.filter((node) => node.type === "ImportDeclaration")
          .at(-1);
        const magic = new MagicString(code);

        magic.appendLeft(
          lastImport?.end ?? 0,
          "\nexport default function () {\n"
        );
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
