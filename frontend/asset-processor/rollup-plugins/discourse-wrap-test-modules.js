import MagicString from "magic-string";
import { wrapTestModuleBody } from "../../discourse/lib/wrap-test-module-body.mjs";

// The test entrypoint also lists helpers, which must keep their exports
const TEST_FILE_REGEX = /-test\.(?:gjs|js|ts|gts)$/;

export function testModuleIdsFor(basePath, testModules = []) {
  return new Set(
    testModules
      .filter((path) => TEST_FILE_REGEX.test(path))
      .map((path) => `${basePath}${path}`)
  );
}

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

        const magic = new MagicString(code);

        wrapTestModuleBody(this.parse(code).body, magic);

        // App modules can end in "-test" too, so the runner needs a marker to tell them apart
        magic.append("export const __discourseTestModule = true;\n");

        return {
          code: magic.toString(),
          map: magic.generateMap({ hires: true }),
        };
      },
    },
  };
}
