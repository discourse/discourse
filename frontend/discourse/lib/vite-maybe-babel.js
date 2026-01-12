import { babel } from "@rollup/plugin-babel";
import { parse as oxcParse } from "oxc-parser";
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
  return babel({
    ...config,
    async filter(id, code) {
      const estree = await oxcParse(id, code);

      let hasDecorators = false;
      let hasBabelRequiredImport = false;

      walk(
        estree.program,
        /* state */ {},
        {
          Decorator(_node, { stop }) {
            hasDecorators = true;
            stop();
          },
          ImportDeclaration(node, { stop }) {
            if (babelRequiredImports.has(node.source.value)) {
              hasBabelRequiredImport = true;
              stop();
            }
          },
        }
      );

      return hasDecorators || hasBabelRequiredImport;
    },
  });
}
