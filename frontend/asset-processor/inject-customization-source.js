// Build-time transform that records which plugin or theme a piece of code came
// from, so the runtime no longer has to infer it from the JavaScript call stack.
//
// For each import of a core API-entry function (see ENTRY_FUNCTIONS) in
// plugin/theme code, it shadows the imported binding with a thin wrapper that
// appends a branded source descriptor as the last argument:
//
//   import { withPluginApi } from "discourse/lib/plugin-api";
//   withPluginApi(cb);
//
// becomes (descriptor abbreviated):
//
//   import { withPluginApi as _customizationSource$withPluginApi } from "...";
//   function withPluginApi(...args) {
//     return _customizationSource$withPluginApi(...args, { ...descriptor });
//   }
//   withPluginApi(cb);
//
// Because the wrapper shadows the import binding, EVERY reference to it is
// attributed — direct calls, aliased imports, a stored alias
// (`const w = withPluginApi`), and the function passed as a callback. The
// matching runtime functions detect the brand, strip the descriptor, and bind
// it to the API object they hand back.
//
// Core code is compiled by a different pipeline and never runs through this
// transform, so it receives no descriptor and resolves to "core".
//
// KNOWN LIMITATIONS (attribution falls back to "core"; the dev-only
// warnIfSourceUnexpected flags them). Attribution flows through the named import
// binding, so it does NOT cover: namespace-member access
// (`import * as api; api.withPluginApi(...)`), dynamic `import()`,
// import-through-a-re-export, or legacy `<script>`-tag plugins (`_pluginCallbacks`
// in app.js, which call withPluginApi from core).

// Registry key for the marker symbol. Keep in sync with SOURCE_BRAND
// (`Symbol.for(...)`) in discourse/lib/customization-source. A registered symbol
// is used so an ordinary object (e.g. a bogus `opts`) can never be mistaken for
// a source descriptor.
const SOURCE_BRAND_KEY = "discourse:customization-source";

// Prefix for the hidden raw-import binding the wrapper forwards to. Also used to
// detect already-shadowed imports so the transform is idempotent.
const RAW_PREFIX = "_customizationSource$";

// The core functions, keyed by their canonical import, that hand a PluginApi to
// plugin/theme code. Extend this list as new source-aware entry points appear.
const ENTRY_FUNCTIONS = [
  { module: "discourse/lib/plugin-api", export: "withPluginApi" },
  { module: "discourse/lib/api", export: "apiInitializer" },
];

export default function (babel, options = {}) {
  const { types: t } = babel;
  const source = options.source;

  if (!source) {
    return { name: "inject-customization-source", visitor: {} };
  }

  function buildDescriptor() {
    const properties = [
      // [Symbol.for("discourse:customization-source")]: true
      t.objectProperty(
        t.callExpression(
          t.memberExpression(t.identifier("Symbol"), t.identifier("for")),
          [t.stringLiteral(SOURCE_BRAND_KEY)]
        ),
        t.booleanLiteral(true),
        true
      ),
      t.objectProperty(t.identifier("type"), t.stringLiteral(source.type)),
    ];

    if (source.type === "plugin") {
      properties.push(
        t.objectProperty(t.identifier("name"), t.stringLiteral(source.name))
      );
    } else if (source.type === "theme") {
      properties.push(
        t.objectProperty(t.identifier("id"), t.numericLiteral(source.id))
      );
    }

    return t.objectExpression(properties);
  }

  function isEntryExport(moduleName, importedName) {
    return ENTRY_FUNCTIONS.some(
      (entry) => entry.module === moduleName && entry.export === importedName
    );
  }

  // Built once per file; cloned into each wrapper.
  const descriptor = buildDescriptor();

  return {
    name: "inject-customization-source",
    visitor: {
      ImportDeclaration(path) {
        const moduleName = path.node.source.value;
        if (!ENTRY_FUNCTIONS.some((entry) => entry.module === moduleName)) {
          return;
        }

        const wrappers = [];

        for (const specifier of path.node.specifiers) {
          if (
            !t.isImportSpecifier(specifier) ||
            !t.isIdentifier(specifier.imported) ||
            !isEntryExport(moduleName, specifier.imported.name)
          ) {
            continue;
          }

          // Already shadowed (e.g. a second transform pass) — leave it alone.
          if (specifier.local.name.startsWith(RAW_PREFIX)) {
            continue;
          }

          const localName = specifier.local.name;
          const rawName = `${RAW_PREFIX}${specifier.imported.name}`;

          // Repoint the import to the hidden raw name; user references keep
          // `localName` and resolve to the wrapper injected below.
          specifier.local = t.identifier(rawName);

          // function <local>(...args) { return <raw>(...args, <descriptor>); }
          wrappers.push(
            t.functionDeclaration(
              t.identifier(localName),
              [t.restElement(t.identifier("args"))],
              t.blockStatement([
                t.returnStatement(
                  t.callExpression(t.identifier(rawName), [
                    t.spreadElement(t.identifier("args")),
                    t.cloneNode(descriptor, true),
                  ])
                ),
              ])
            )
          );
        }

        if (wrappers.length > 0) {
          // Rebuild scope so the now-repointed import (raw name) replaces the
          // stale original-name binding; otherwise inserting the wrapper under
          // the original name is seen as a duplicate declaration. References keep
          // their original names and resolve to the hoisted wrappers.
          path.scope.crawl();
          path.insertAfter(wrappers);
        }
      },
    },
  };
}
