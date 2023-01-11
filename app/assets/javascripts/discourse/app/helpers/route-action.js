import { A } from "@ember/array";
import Helper from "@ember/component/helper";
import { computed, get } from "@ember/object";
import { getOwner } from "@ember/application";
import { join } from "@ember/runloop";
import { assert, runInDebug } from "@ember/debug";

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

export function routeAction(actionName, router, ...params) {
  assert("[ember-route-action-helper] Unable to lookup router", router);

  runInDebug(() => {
    let { handler } = getRouteWithAction(router, actionName);
    assert(
      `[ember-route-action-helper] Unable to find action ${actionName}`,
      handler
    );
  });

  return function (...invocationArgs) {
    let { action, handler } = getRouteWithAction(router, actionName);
    let args = params.concat(invocationArgs);
    return join(handler, action, ...args);
  };
}

export default Helper.extend({
  router: computed({
    get() {
      return getOwner(this).lookup("router:main");
    },
  }),

  compute([actionName, ...params]) {
    return routeAction(actionName, get(this, "router"), ...params);
  },
});
