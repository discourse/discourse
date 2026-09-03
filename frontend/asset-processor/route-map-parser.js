// Route maps are parsed, never run: plugin and theme code is not trusted enough to evaluate here.
// `mapping-router.js` is the reference for what a map means, and these rules can drift from it.

// `BareRouter#lazyRoute` dasherizes before matching, so derived names have to agree.
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

function fail(context, node, message) {
  const { line, column } = positionOf(context.source, node.start);
  throw new Error(
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

  return { name: nameNode.value, options, children };
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

    // Core's maps build routes in loops. Those routes are missing from the derived tree.
    if (context.lenient) {
      continue;
    }

    fail(
      context,
      statement,
      "a route map may only contain this.route calls with literal arguments"
    );
  }

  return routes;
}

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
    return {
      resource: null,
      bundleName: null,
      routes: readBody(context, declaration.body),
    };
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
  const bundleName = declaration.properties.find(
    (property) =>
      property.type === "Property" && keyName(property) === "bundleName"
  );

  if (
    bundleName &&
    (bundleName.value.type !== "Literal" ||
      typeof bundleName.value.value !== "string")
  ) {
    fail(context, bundleName.value, "`bundleName` must be a string literal");
  }

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

  // `mapping-router.js` reads only `resource` and `map`, so the rest is ours to use.
  return {
    resource: resource.value.value,
    bundleName: bundleName?.value.value ?? null,
    routes: readBody(context, map.value.body),
  };
}

// Mirrors `RouteNode`: a child with the same name is merged into, so several maps can extend
// one route.
function addRoutes(parent, routes, core, bundleName = null) {
  for (const route of routes) {
    let node = parent.byName.get(route.name);

    if (!node) {
      const options = { ...route.options };

      if (bundleName && options.bundleName === undefined) {
        options.bundleName = bundleName;
      }

      node = {
        name: route.name,
        options,
        core,
        byName: new Map(),
      };
      parent.byName.set(route.name, node);
    }

    // Only the map's own top level is seeded, because everything below it inherits.
    addRoutes(node, route.children, core);
  }
}

// `resource` walks the names given to `this.route`, which are not route names:
// `admin.adminPlugins.show` reaches a route named `adminPlugins.show`.
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
  const root = { name: "root", options: {}, byName: new Map() };
  const unmounted = [];

  for (const map of maps.filter((candidate) => !candidate.resource)) {
    addRoutes(root, map.routes, map.core, map.bundleName);
  }

  for (const map of maps.filter((candidate) => candidate.resource)) {
    const node = findPath(root, map.resource);

    if (node) {
      addRoutes(node, map.routes, map.core, map.bundleName);
    } else {
      unmounted.push(map);
    }
  }

  return { root, unmounted };
}

function joinUrl(parent, path) {
  return [...parent.split("/"), ...path.split("/")].filter(Boolean).join("/");
}

// `Plugin::JsManager.url_glob_pattern` reads `*` as one segment and `**` as one or more.
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

// Nothing a plugin declares is eager, so a route naming no bundle still falls into one.
const DEFAULT_BUNDLE_NAME = "default";

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
      });

      walk(node.byName.values(), { name, url, bundleName });
    }
  }

  walk(root.byName.values(), { name: "", url: "", bundleName: null });

  return derived;
}

function literalSegments(glob) {
  return glob.split("/").filter((segment) => !/^\*\*?$/.test(segment)).length;
}

function segmentCount(glob) {
  return glob.split("/").length;
}

// A glob a shallower one in the same bundle already covers adds nothing.
function urlsFor(globs) {
  const sorted = [...new Set(globs)].sort();

  return sorted.filter(
    (glob) =>
      !sorted.some((other) => other !== glob && glob.startsWith(`${other}/`))
  );
}

export function bundleByRouteFor(derived) {
  const bundleByRoute = {};

  for (const route of derived) {
    if (route.bundleName) {
      bundleByRoute[route.name] = route.bundleName;
    }
  }

  return bundleByRoute;
}

// Urls come out most specific first, so the first match wins whatever order routes were declared.
export function urlTableFor(derived) {
  const globsByBundle = new Map();

  for (const route of derived) {
    if (!route.bundleName) {
      continue;
    }

    const globs = globsByBundle.get(route.bundleName) ?? [];
    globs.push(globFor(route.url));
    globsByBundle.set(route.bundleName, globs);
  }

  return [...globsByBundle]
    .flatMap(([bundleName, globs]) =>
      urlsFor(globs).map((glob) => ({ bundleName, url: `${glob}/*` }))
    )
    .sort(
      (a, b) =>
        literalSegments(b.url) - literalSegments(a.url) ||
        segmentCount(b.url) - segmentCount(a.url)
    );
}
