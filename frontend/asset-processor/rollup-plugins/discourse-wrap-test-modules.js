import MagicString from "magic-string";
import {
  TEST_MODULE_EXPORTS_ERROR,
  wrapTestModuleBody,
} from "../../discourse/lib/wrap-test-module-body.mjs";

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

        if (wrapTestModuleBody(this.parse(code).body, magic)) {
          // The runner must distinguish tests from app modules also named "*-test".
          magic.append("export const __discourseTestModule = true;\n");
        } else {
          // Throwing would fail the whole plugin build, app code included. Left eager, the
          // module keeps its importers linking, and the runner reports this as a failing test.
          magic.append(
            `export const __discourseTestModuleError = ${JSON.stringify(TEST_MODULE_EXPORTS_ERROR)};\n`
          );
        }

        return {
          code: magic.toString(),
          map: magic.generateMap({ hires: true }),
        };
      },
    },
  };
}
