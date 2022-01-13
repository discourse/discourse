import EmberRouter from "@ember/routing/router";
import Site from "discourse/models/site";
import { defaultHomepage } from "discourse/lib/utilities";
import getURL from "discourse-common/lib/get-url";
import { isTesting } from "discourse-common/config/environment";
import { rewritePath } from "discourse/lib/url";

const BareRouter = EmberRouter.extend({
  location: isTesting() ? "none" : "discourse-location",

  handleURL(url) {
    url = rewritePath(url);
    const params = url.split("?");

    if (params[0] === "/" || params[0] === "") {
      url = defaultHomepage();
      if (params[1] && params[1].length) {
        url = `${url}?${params[1]}`;
      }
    }
    return this._super(url);
  },
});

// Ember's router can't be extended. We need to allow plugins to add routes to routes that were defined
// in the core app. This class has the same API as Ember's `Router.map` but saves the results in a tree.
// The tree is applied after all plugins are defined.
class RouteNode {
  constructor(name, opts = {}, depth = 0) {
    this.name = name;
    this.opts = opts;
    this.depth = depth;
    this.children = [];
    this.childrenByName = {};
    this.paths = {};
    this.site = Site.current();

    if (!opts.path) {
      opts.path = name;
    }

    this.paths[opts.path] = true;
  }

  route(name, opts, fn) {
    if (typeof opts === "function") {
      fn = opts;
      opts = {};
    } else {
      opts = opts || {};
    }

    const existing = this.childrenByName[name];
    if (existing) {
      if (opts.path) {
        existing.paths[opts.path] = true;
      }
      existing.extract(fn);
    } else {
      const node = new RouteNode(name, opts, this.depth + 1);
      node.extract(fn);
      this.childrenByName[name] = node;
      this.children.push(node);
    }
  }

  extract(fn) {
    if (!fn) {
      return;
    }
    fn.call(this);
  }

  mapRoutes(router) {
    const children = this.children;
    if (this.name === "root") {
      children.forEach((c) => c.mapRoutes(router));
    } else {
      const builder =
        children.length === 0
          ? undefined
          : function () {
              children.forEach((c) => c.mapRoutes(this));
            };
      router.route(this.name, this.opts, builder);
    }
  }

  findSegment(segments) {
    if (segments && segments.length) {
      const first = segments.shift();
      const node = this.childrenByName[first];
      if (node) {
        return segments.length === 0 ? node : node.findSegment(segments);
      }
    }
  }

  findPath(path) {
    if (path) {
      return this.findSegment(path.split("."));
    }
  }
}

export function mapRoutes() {
  const tree = new RouteNode("root");
  const extras = [];

  // If a module is defined as `route-map` in discourse or a plugin, its routes
  // will be built automatically. You can supply a `resource` property to
  // automatically put it in that resource, such as `admin`. That way plugins
  // can define admin routes.
  Object.keys(requirejs._eak_seen).forEach(function (key) {
    if (/route-map$/.test(key)) {
      let module = requirejs(key, null, null, true);
      if (!module || !module.default) {
        throw new Error(key + " must export a route map.");
      }

      const mapObj = module.default;
      if (typeof mapObj === "function") {
        tree.extract(mapObj);
      } else {
        extras.push(mapObj);
      }
    }
  });

  extras.forEach((extra) => {
    let node = tree.findPath(extra.resource);
    if (node) {
      node.extract(extra.map);
    }
  });

  return BareRouter.extend({
    rootURL: getURL("/"),
  }).map(function () {
    tree.mapRoutes(this);
    this.route("unknown", { path: "*path" });
  });
}
export function teardownRouter(routerClass) {
  routerClass.dslCallbacks.splice(0, routerClass.dslCallbacks.length);
}

export function registerRouter(registry) {
  registry.unregister("router:main");
  let router = mapRoutes();

  registry.register("router:main", router);
  return router;
}
