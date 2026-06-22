// Build-time transform that records which plugin or theme a piece of code came
// from, so the runtime no longer has to infer it from the JavaScript call stack.
//
// For every call to one of the core API-entry functions (see ENTRY_FUNCTIONS)
// made from plugin/theme code, it appends a branded source descriptor as the
// last argument. The matching runtime functions detect the brand, strip the
// descriptor, and bind it to the API object they hand back.
//
// Core code is compiled by a different pipeline and never runs through this
// transform, so it receives no descriptor and resolves to "core".

// Registry key for the marker symbol. Keep in sync with SOURCE_BRAND
// (`Symbol.for(...)`) in discourse/lib/customization-source. A registered symbol
// is used so an ordinary object (e.g. a bogus `opts`) can never be mistaken for
// a source descriptor.
const SOURCE_BRAND_KEY = "discourse:customization-source";

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

  function brandKey() {
    return t.callExpression(
      t.memberExpression(t.identifier("Symbol"), t.identifier("for")),
      [t.stringLiteral(SOURCE_BRAND_KEY)]
    );
  }

  function isBrandKey(node) {
    return (
      t.isCallExpression(node) &&
      t.isMemberExpression(node.callee) &&
      t.isIdentifier(node.callee.object, { name: "Symbol" }) &&
      t.isIdentifier(node.callee.property, { name: "for" }) &&
      node.arguments.length === 1 &&
      t.isStringLiteral(node.arguments[0], { value: SOURCE_BRAND_KEY })
    );
  }

  function buildDescriptor() {
    const properties = [
      // [Symbol.for("discourse:customization-source")]: true
      t.objectProperty(brandKey(), t.booleanLiteral(true), true),
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

  function isEntryCall(path) {
    const callee = path.node.callee;
    if (!t.isIdentifier(callee)) {
      return false;
    }

    const binding = path.scope.getBinding(callee.name);
    if (!binding || binding.kind !== "module") {
      return false;
    }

    const specifier = binding.path;
    if (!t.isImportSpecifier(specifier.node)) {
      return false;
    }

    const importedName = specifier.node.imported.name;
    const moduleName = specifier.parent.source.value;

    return ENTRY_FUNCTIONS.some(
      (entry) => entry.export === importedName && entry.module === moduleName
    );
  }

  function alreadyBranded(args) {
    const last = args[args.length - 1];
    return (
      last &&
      t.isObjectExpression(last) &&
      last.properties.some(
        (property) =>
          t.isObjectProperty(property) &&
          property.computed &&
          isBrandKey(property.key)
      )
    );
  }

  return {
    name: "inject-customization-source",
    visitor: {
      CallExpression(path) {
        if (!isEntryCall(path) || alreadyBranded(path.node.arguments)) {
          return;
        }
        path.node.arguments.push(buildDescriptor());
      },
    },
  };
}
