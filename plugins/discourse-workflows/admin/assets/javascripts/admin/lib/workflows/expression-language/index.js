import { waitForPromise } from "@ember/test-waiters";
import { loadCodeEditorLanguage } from "discourse/lib/code-editor-languages";

let pending;
let build;

// Extension builders run synchronously when the editor is created, so the
// grammar, its helpers and the nested JavaScript parser must be loaded first.
export function loadExpressionLanguage() {
  pending ??= waitForPromise(
    Promise.all([
      loadCodeEditorLanguage("javascript"),
      import("./expression-utils.js"),
    ]).then(
      ([javascript, { buildExpressionUtils }]) => {
        build = (cmParams) => buildExpressionUtils(cmParams, javascript);
      },
      (error) => {
        pending = null;
        throw error;
      }
    )
  );

  return pending;
}

export function expressionUtils(cmParams) {
  if (!build) {
    throw new Error(
      "loadExpressionLanguage() must resolve before building expression extensions"
    );
  }
  return build(cmParams);
}
