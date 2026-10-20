/**
 * Shared by the core test build and the plugin asset processor, which use different
 * bundlers and code editors. Both defer registration until the runner selects a file.
 *
 * @param {Array<object>} body - The module's top-level ESTree statements
 * @param {object} magic - An editor over the module's code with `move`, `prependRight` and `append`
 * @throws {Error} When the module has exports, which cannot be deferred inside the function
 */
export function wrapTestModuleBody(body, magic) {
  if (body.some((node) => node.type.startsWith("Export"))) {
    throw new Error(
      "Test modules cannot contain exports. Move shared helpers into a separate helper module and import them."
    );
  }

  let wrapStart = 0;
  let inBody = false;

  for (const node of body) {
    if (node.type !== "ImportDeclaration") {
      inBody = true;
    } else if (inBody) {
      // Generated imports can follow statements but must stay outside the wrapper.
      magic.move(node.start, node.end, wrapStart);
    } else {
      wrapStart = node.end;
    }
  }

  // `prependRight` keeps the moved imports ahead of the wrapper
  magic.prependRight(wrapStart, "\nexport default async function () {\n");
  magic.append("\n}\n");
}
