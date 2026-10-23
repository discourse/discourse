import { id, include } from "@rolldown/pluginutils";

// Ember 7 ships separate dev/prod builds. The prod build hard-codes the
// deprecation machinery to no-ops (`@ember/debug`'s `deprecate`/handlers become
// `() => {}`, and `deprecateUntil` drops its `deprecate()` call), so Ember
// deprecations never fire in production. Discourse relies on them for production
// deprecation telemetry - the previous classic build kept them via an
// ember-source patch.
//
// Restore that behaviour surgically: in production builds, redirect just these
// deprecation modules from ember-source's prod dist to its (functionally
// complete) dev dist. Their relative imports (handlers, assert, the debug
// barrel) resolve within the dev tree automatically. The rest of ember stays on
// the optimized prod build.
const PROD = "/dist/prod/packages/";
const DEV = "/dist/dev/packages/";

const TARGETS = [
  "@ember/-internals/deprecations/index.js",
  "@ember/debug/lib/deprecate.js",
  "@ember/debug/lib/handlers.js",
];

// Native (Rust-side) pre-filter on the import specifier, so the JS handler
// only runs for imports that could resolve to a target module - avoiding a
// round-trip for every module in the build. The specifiers reaching the
// targets are relative (`./deprecate.js`, `../../debug/lib/handlers.js`) or the
// `@ember/-internals/deprecations` bare specifier.
const SPECIFIER = /deprecate|handlers|-internals\/deprecations/;

export default function productionEmberDeprecations() {
  return {
    name: "production-ember-deprecations",
    resolveId: {
      filter: [include(id(SPECIFIER))],
      async handler(source, importer, options) {
        if (!importer) {
          return null;
        }

        const resolved = await this.resolve(source, importer, {
          ...options,
          skipSelf: true,
        });
        if (!resolved || resolved.external) {
          return null;
        }

        if (TARGETS.some((target) => resolved.id.endsWith(PROD + target))) {
          return { ...resolved, id: resolved.id.replace(PROD, DEV) };
        }

        return null;
      },
    },
  };
}
