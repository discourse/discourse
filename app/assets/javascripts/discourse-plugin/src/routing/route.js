import { createCache, getValue } from "@glimmer/tracking/primitives/cache";
import { assert, runInDebug } from "@ember/debug";
import BaseRoute from "ember-polaris-routing/route";
import Task from "ember-tasks";

export default class Route extends BaseRoute {
  // We could have used `@cached get promise`, but this addon currently does
  // not have decorators set up :(
  #task = createCache(() => Task.promise(this.load()));

  #emberRoute;

  constructor(router, params, emberRoute) {
    super(router, params);
    this.#emberRoute = emberRoute;
  }

  async load() {}

  get promise() {
    return getValue(this.#task).promise;
  }

  get isLoading() {
    return getValue(this.#task).pending;
  }

  get isLoaded() {
    return getValue(this.#task).resolved;
  }

  get isError() {
    return getValue(this.#task).terminated;
  }

  get model() {
    return getValue(this.#task).value;
  }

  get error() {
    return getValue(this.#task).reason;
  }

  async modelFor(routeName) {
    return await this.routeFor(routeName)?.promise;
  }

  paramsFor(routeName) {
    return this.routeFor(routeName)?.params;
  }

  routeFor(routeName) {
    runInDebug(() => {
      const [pluginPrefix] = this.#routeName.split(".");
      const [requestPrefix] = routeName.split(".");

      assert(
        `The route "${this.#routeName}" attempted to resolve the route ` +
          `"${routeName}" but this is not allowed. v2 plugins can only ` +
          `interact with their own routes.`,
        pluginPrefix === requestPrefix
      );
    });

    return this.#emberRoute.modelFor(routeName);
  }

  #routeName() {
    return this.#emberRoute.routeName;
  }
}
