import { withPluginApi } from "discourse/lib/plugin-api";

/**
 * apiInitializer(version, apiCodeCallback, opts)
 *
 * An API to simplify the creation of initializers for plugins/themes by removing
 * some of the boilerplate.
 */
let _apiInitializerId = 0;
export function apiInitializer(version, cb, opts) {
  return {
    name: `api-initializer${_apiInitializerId++}`,
    after: "inject-objects",
    initialize() {
      return withPluginApi(version, cb, opts);
    },
  };
}
