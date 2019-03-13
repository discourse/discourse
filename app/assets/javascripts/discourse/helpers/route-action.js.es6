const {
  A: emberArray,
  Helper,
  assert,
  computed,
  get,
  getOwner,
  run,
  runInDebug
} = Ember;

function getCurrentHandlerInfos(router) {
  let routerLib = router._routerMicrolib || router.router;

  return routerLib.currentHandlerInfos;
}

function getRoutes(router) {
  return emberArray(getCurrentHandlerInfos(router))
    .mapBy("handler")
    .reverse();
}

function getRouteWithAction(router, actionName) {
  let action;
  let handler = emberArray(getRoutes(router)).find(route => {
    let actions = route.actions || route._actions;
    action = actions[actionName];

    return typeof action === "function";
  });

  return { action, handler };
}

export default Helper.extend({
  router: computed(function() {
    return getOwner(this).lookup("router:main");
  }).readOnly(),

  compute([actionName, ...params]) {
    let router = get(this, "router");
    assert("[ember-route-action-helper] Unable to lookup router", router);

    runInDebug(() => {
      let { handler } = getRouteWithAction(router, actionName);
      assert(
        `[ember-route-action-helper] Unable to find action ${actionName}`,
        handler
      );
    });

    let routeAction = function(...invocationArgs) {
      let { action, handler } = getRouteWithAction(router, actionName);
      let args = params.concat(invocationArgs);
      return run.join(handler, action, ...args);
    };

    return routeAction;
  }
});
