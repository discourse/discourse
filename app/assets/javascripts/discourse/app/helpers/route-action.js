/* eslint-disable ember/no-private-routing-service */
import { A } from "@ember/array";
import Helper from "@ember/component/helper";
import { assert, runInDebug } from "@ember/debug";
import { computed, get } from "@ember/object";
import { getOwner } from "@ember/owner";
import { join } from "@ember/runloop";
import { isTesting } from "discourse/lib/environment";

function getCurrentRouteInfos(router) {
  let routerLib = router._routerMicrolib || router.router;
  return routerLib.currentRouteInfos;
}

function getRoutes(router) {
  return A(getCurrentRouteInfos(router)).mapBy("_route").reverse();
}

function getRouteWithAction(router, actionName) {
  let action;
  let handler = A(getRoutes(router)).find((route) => {
    let actions = route.actions || route._actions;
    action = actions[actionName];

    return typeof action === "function";
  });

  return { action, handler };
}

function routeAction(actionName, router, ...params) {
  assert("[ember-route-action-helper] Unable to lookup router", router);

  if (!isTesting() || router.currentRoute) {
    runInDebug(() => {
      let { handler } = getRouteWithAction(router, actionName);
      assert(
        `[ember-route-action-helper] Unable to find action ${actionName}`,
        handler
      );
    });
  }

  return function (...invocationArgs) {
    let { action, handler } = getRouteWithAction(router, actionName);
    let args = params.concat(invocationArgs);
    return join(handler, action, ...args);
  };
}

export default class RouteAction extends Helper {
  @computed
  get router() {
    return getOwner(this).lookup("router:main");
  }

  compute([actionName, ...params]) {
    return routeAction(actionName, get(this, "router"), ...params);
  }
}
