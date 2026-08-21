// Route maps are parsed, never run: plugin and theme code is not trusted enough to evaluate in
// the asset processor. `mapping-router.js` stays the reference for what a map means, and the
// rules below restate it — the two can drift, which is what the parity test guards.

// Ember's `dasherize`, which `BareRouter#lazyRoute` applies before matching a lazy route name.
function dasherize(value) {
  return value
    .replace(/([a-z\d])([A-Z])/g, "$1-$2")
    .replace(/_/g, "-")
    .toLowerCase();
}

function positionOf(source, offset) {
  const upTo = source.slice(0, offset);
  const line = upTo.split("\n").length;
  return { line, column: offset - (upTo.lastIndexOf("\n") + 1) + 1 };
}

class RouteMapError extends Error {}

function fail(context, node, message) {
  const { line, column } = positionOf(context.source, node.start);
  throw new RouteMapError(
    `[${context.label}] ${context.filename}:${line}:${column} — ${message}`
  );
}

const FUNCTION_TYPES = ["FunctionExpression", "FunctionDeclaration"];

function keyName(property) {
  return property.key.name ?? property.key.value;
}

function isThisRouteCall(node) {
  return (
    node.type === "CallExpression" &&
    node.callee.type === "MemberExpression" &&
    !node.callee.computed &&
    node.callee.object.type === "ThisExpression" &&
    node.callee.property.name === "route"
  );
}

function readOptions(context, node) {
  const options = {};

  for (const property of node.properties) {
    if (property.type !== "Property" || property.computed) {
      fail(context, property, "route options must be plain literal properties");
    }

    if (property.value.type !== "Literal") {
      fail(
        context,
        property.value,
        `option "${keyName(property)}" must be a literal`
      );
    }

    options[keyName(property)] = property.value.value;
  }

  return options;
}

function readRouteCall(context, node) {
  const [nameNode, ...rest] = node.arguments;

  if (nameNode?.type !== "Literal" || typeof nameNode.value !== "string") {
    fail(context, nameNode ?? node, "route name must be a string literal");
  }

  let options = {};
  let children = [];

  for (const argument of rest) {
    if (argument.type === "ObjectExpression") {
      options = readOptions(context, argument);
    } else if (FUNCTION_TYPES.includes(argument.type)) {
      children = readBody(context, argument.body);
    } else if (argument.type === "ArrowFunctionExpression") {
      // `this` inside an arrow is the enclosing scope, so the DSL cannot work there.
      fail(context, argument, "route callback must be a function expression");
    } else {
      fail(context, argument, "unexpected argument to this.route");
    }
  }

  return { name: nameNode.value, options, children, node };
}

function readBody(context, block) {
  const routes = [];

  for (const statement of block.body) {
    if (
      statement.type === "ExpressionStatement" &&
      isThisRouteCall(statement.expression)
    ) {
      routes.push(readRouteCall(context, statement.expression));
      continue;
    }

    // Core's maps generate routes from site settings in loops the parser cannot read. Those
    // routes are absent from the derived tree, which is a known gap.
    if (context.lenient) {
      continue;
    }

    fail(
      context,
      statement,
      "a route map may only contain this.route calls — see plugin-v2-route-map-bundles.md"
    );
  }

  return routes;
}

// One `*-route-map` module. Returns the routes it declares, and the tree path it mounts on.
export function parseRouteMap(
  ast,
  { filename, source, label, lenient = false }
) {
  const context = { filename, source, label, lenient };

  const exported = ast.body.find(
    (node) => node.type === "ExportDefaultDeclaration"
  );

  if (!exported) {
    fail(context, ast.body[0] ?? { start: 0 }, "no default export");
  }

  const declaration = exported.declaration;

  if (FUNCTION_TYPES.includes(declaration.type)) {
    return { resource: null, routes: readBody(context, declaration.body) };
  }

  if (declaration.type !== "ObjectExpression") {
    fail(
      context,
      declaration,
      "a route map must export a function or an object"
    );
  }

  const resource = declaration.properties.find(
    (property) =>
      property.type === "Property" && keyName(property) === "resource"
  );
  const map = declaration.properties.find(
    (property) => property.type === "Property" && keyName(property) === "map"
  );

  if (!resource || resource.value.type !== "Literal") {
    fail(
      context,
      resource ?? declaration,
      "`resource` must be a string literal"
    );
  }

  if (!map || !FUNCTION_TYPES.includes(map.value.type)) {
    fail(context, map ?? declaration, "`map` must be a function");
  }

  // `extra.path` is set on some of these and ignored by `mapping-router.js`.
  return {
    resource: resource.value.value,
    routes: readBody(context, map.value.body),
  };
}

export { RouteMapError };

// Mirrors `RouteNode` in `mapping-router.js`: a child with the same name is merged into, not
// duplicated, so several maps can extend one route.
function addRoutes(parent, routes, core) {
  for (const route of routes) {
    let node = parent.byName.get(route.name);

    if (!node) {
      node = {
        name: route.name,
        options: { ...route.options },
        core,
        children: [],
        byName: new Map(),
      };
      parent.byName.set(route.name, node);
      parent.children.push(node);
    }

    addRoutes(node, route.children, core);
  }
}

// `resource` names a path through the tree by the names given to `this.route`, which is not the
// same as a route name: `admin.adminPlugins.show` walks to a route named `adminPlugins.show`.
function findPath(root, resource) {
  let node = root;

  for (const segment of resource.split(".")) {
    node = node.byName.get(segment);

    if (!node) {
      return null;
    }
  }

  return node;
}

export function buildRouteTree(maps) {
  const root = { name: "root", options: {}, children: [], byName: new Map() };
  const mounted = [];
  const unmounted = [];

  for (const map of maps.filter((candidate) => !candidate.resource)) {
    addRoutes(root, map.routes, map.core);
  }

  for (const map of maps.filter((candidate) => candidate.resource)) {
    const node = findPath(root, map.resource);

    if (node) {
      addRoutes(node, map.routes, map.core);
      mounted.push(map);
    } else {
      unmounted.push(map);
    }
  }

  return { root, mounted, unmounted };
}

function joinUrl(parent, path) {
  return [...parent.split("/"), ...path.split("/")].filter(Boolean).join("/");
}

// A `:dynamic` segment becomes `*`, which `url_glob_matches?` reads as exactly one segment. A
// `*splat` eats the rest of the route's path, so it becomes `**`, which reads as one or more.
function globFor(url) {
  return url
    .split("/")
    .map((segment) => {
      if (segment.startsWith("*")) {
        return "**";
      }

      return segment.startsWith(":") ? "*" : segment;
    })
    .join("/");
}

// A plugin route with no `bundleName` in its ancestry still gets a bundle. Nothing a plugin
// declares belongs in the eager set, so this is the bundle everything else falls into.
export const DEFAULT_BUNDLE_NAME = "default";

export function deriveRoutes(root) {
  const derived = [];

  function walk(nodes, parent) {
    for (const node of nodes) {
      const { options } = node;

      const name =
        options.resetNamespace || !parent.name
          ? node.name
          : `${parent.name}.${node.name}`;
      const url = joinUrl(parent.url, options.path ?? node.name);
      const bundleName =
        options.bundleName ??
        parent.bundleName ??
        (node.core ? null : DEFAULT_BUNDLE_NAME);

      derived.push({
        name: dasherize(name),
        url,
        bundleName,
        declaresBundle: options.bundleName !== undefined,
      });

      walk(node.children, { name, url, bundleName });
    }
  }

  walk(root.children, { name: "", url: "", bundleName: null });

  return derived;
}

function literalSegments(glob) {
  return glob.split("/").filter((segment) => !/^\*\*?$/.test(segment)).length;
}

// One url per bundle entry point. A glob already covered by a shallower one in the same bundle
// adds nothing, because every url matches its own descendants.
function urlsFor(globs) {
  const sorted = [...new Set(globs)].sort();

  return sorted.filter(
    (glob) =>
      !sorted.some((other) => other !== glob && glob.startsWith(`${other}/`))
  );
}

// Route name to bundle, and the urls that reach each bundle. Urls are ordered most specific
// first, so the first match wins correctly whatever order the routes were declared in.
export function routeTablesFor(derived) {
  const bundleByRoute = {};
  const globsByBundle = new Map();

  for (const route of derived) {
    if (!route.bundleName) {
      continue;
    }

    bundleByRoute[route.name] = route.bundleName;

    const globs = globsByBundle.get(route.bundleName) ?? [];
    globs.push(globFor(route.url));
    globsByBundle.set(route.bundleName, globs);
  }

  const urls = [...globsByBundle]
    .flatMap(([bundleName, globs]) =>
      urlsFor(globs).map((glob) => ({ bundleName, url: `${glob}/*` }))
    )
    .sort((a, b) => literalSegments(b.url) - literalSegments(a.url));

  return { bundleByRoute, urls };
}
