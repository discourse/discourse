import { setComponentManager } from "@ember/component";

function throwUsageError() {
  throw new Error(
    "stripWhitespace should be imported without renaming, and must be used as a block in a template."
  );
}

/**
 * Remove all whitespace from inside `{{#stripWhitespace}}...{{/stripWhitespace}}` blocks
 */
export default function stripWhitespace() {
  // Noop helper. This is just a marker for the AST transform.
  throwUsageError();
}

setComponentManager(() => {
  throwUsageError();
}, stripWhitespace);

export function _checkStripWhitespace(func) {
  if (func !== stripWhitespace) {
    throwUsageError();
  }
}
