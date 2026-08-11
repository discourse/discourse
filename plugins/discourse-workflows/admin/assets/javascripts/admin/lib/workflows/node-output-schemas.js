// Nodes whose output keys come from what the author typed cannot declare them as a contract, so
// they compute them in Ruby and name an editor-side counterpart through `output_schema_resolver`.
const RESOLVER_MODULE = /\/admin\/lib\/workflows\/output-schemas\/([\w-]+)$/;

let cache;

function resolverFor(name) {
  cache ??= Object.keys(require.entries).reduce((resolvers, moduleName) => {
    const match = moduleName.match(RESOLVER_MODULE);
    if (match) {
      resolvers[match[1]] = moduleName;
    }
    return resolvers;
  }, {});

  const moduleName = cache[name];
  return moduleName ? require(moduleName).default : null;
}

export function outputSchemasFromResolver(resolver, configuration = {}) {
  if (!resolver) {
    return null;
  }

  return resolverFor(resolver)?.(configuration || {}) || null;
}
