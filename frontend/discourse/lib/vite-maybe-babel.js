import { babel } from "@rollup/plugin-babel";
import { walk } from "zimmerframe";

const babelRequiredImports = new Set([
  // Templates
  "@ember/template-compiler",
  "@ember/template-compilation",
  "ember-cli-htmlbars",
  "ember-cli-htmlbars-inline-precompile",
  "htmlbars-inline-precompile",

  // Macros
  "@embroider/macros",
  "@glimmer/env",
  "@ember/debug",
  "@ember/application/deprecations",
]);

export default function maybeBabel(config) {
  let totalFiles = 0;
  let skippedFiles = 0;
  let decoratorsWithNoImports = 0;

  const original = babel(config);
  return {
    ...original,
    async transform(code, id) {
      // console.log(this.environment);
      if (!config.extensions.some((ext) => id.endsWith(ext))) {
        return null;
      }

      const estree = this.parse(code);

      let hasDecorators = false;
      let hasBabelRequiredImport = false;

      walk(
        estree,
        {},
        {
          _(node, { state, next }) {
            if (node.decorators?.length) {
              hasDecorators = true;
            } else {
              next(state);
            }
          },
          ImportDeclaration(node) {
            if (babelRequiredImports.has(node.source.value)) {
              hasBabelRequiredImport = true;
            }
          },
        }
      );

      totalFiles += 1;

      if (hasDecorators && !hasBabelRequiredImport) {
        decoratorsWithNoImports += 1;
      }

      if (hasDecorators || hasBabelRequiredImport) {
        return original.transform.call(this, code, id);
      } else {
        skippedFiles += 1;
      }
    },
    buildEnd() {
      // eslint-disable-next-line no-console
      console.log(
        `[maybe-babel] Processed ${totalFiles - skippedFiles} of ${totalFiles} files. (${decoratorsWithNoImports} files had decorators but no required imports.)`
      );
    },
  };
}
