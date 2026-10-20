import { wrapTestModuleBody } from "./wrap-test-module-body.mjs";

const TEST_FILE_RE = /tests\/(?!helpers\/).*-test\.(?:gjs|js|ts|gts)$/;

export default function wrapTestModulesPlugin() {
  return {
    name: "wrap-test-modules",
    transform: {
      filter: { id: TEST_FILE_RE },
      handler(code, id, { ast, magicString }) {
        wrapTestModuleBody(ast.body, magicString);

        return {
          code: magicString,
        };
      },
    },
  };
}
