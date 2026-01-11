import { tracked } from "@glimmer/tracking";
import { getOwner } from "@ember/owner";
import Service from "@ember/service";

export default class RouteTreeService extends Service {
  @tracked treeVersion = 0;

  _routeTreeRaw = null;

  _flatRoutesRaw = null;

  get routeTree() {
    this.treeVersion;
    if (this._routeTreeRaw) {
      return this._routeTreeRaw;
    }
    this._buildRouteTree();
    return this._routeTreeRaw || {};
  }

  get flatRoutes() {
    this.treeVersion;
    if (this._flatRoutesRaw) {
      return this._flatRoutesRaw;
    }
    this._buildRouteTree();
    return this._flatRoutesRaw || [];
  }

  _buildRouteTree() {
    const recognizer = this._getRecognizer();
    if (!recognizer) {
      this._routeTree = {};
      this._flatRoutes = [];
      return;
    }

    const tree = {};
    const names = recognizer.names;
    const routeNames = Object.keys(names);
    this._flatRoutesRaw = routeNames;

    routeNames.forEach((routeName) => {
      const handlers = recognizer.handlersFor(routeName);
      if (!handlers) {
        return;
      }

      const hasFilteredRoute = handlers.some((h) => {
        const name = h.handler;
        return name.endsWith("_error") || name.endsWith("_loading");
      });

      if (hasFilteredRoute) {
        return;
      }

      const paramNames = this._extractParamNames(handlers);
      const requiresParams = paramNames.length > 0;

      let cursor = tree;

      handlers.forEach((h, index) => {
        const name = h.handler;
        if (!cursor[name]) {
          cursor[name] = {};
        }
        cursor = cursor[name];

        if (!cursor.__meta) {
          cursor.__meta = {};
        }

        if (index === handlers.length - 1) {
          cursor.__meta.requiresParams = requiresParams;
          cursor.__meta.paramNames = paramNames;
        }
      });
    });

    this._routeTreeRaw = tree;
  }

  _extractParamNames(handlers) {
    const names = handlers.flatMap((h) => h.names || []);
    return [...new Set(names)];
  }

  _getRecognizer() {
    const owner = getOwner(this);
    const routerMain = owner.lookup("router:main");
    const microlib =
      routerMain && (routerMain._routerMicrolib || routerMain.router);

    return microlib && microlib.recognizer;
  }

  invalidateCache() {
    this._routeTree = null;
    this._flatRoutes = null;
  }
}
