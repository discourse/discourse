import MagicString from "magic-string";
import { wrapTestModuleBody } from "../../discourse/lib/wrap-test-module-body.mjs";

// Helpers share the test entrypoint and must keep their exports.
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
      // Parse after template and syntax transforms produce plain JS.
      order: "post",

      handler(code, id) {
        if (!testModuleIds.has(id)) {
          return null;
        }

        const magic = new MagicString(code);

        wrapTestModuleBody(this.parse(code).body, magic);

        // The runner must distinguish tests from app modules also named "*-test".
        magic.append("export const __discourseTestModule = true;\n");

        return {
          code: magic.toString(),
          map: magic.generateMap({ hires: true }),
        };
      },
    },
  };
}
