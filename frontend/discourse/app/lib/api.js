// @ts-check
import { withPluginApi } from "discourse/lib/plugin-api";

let _apiInitializerId = 0;

/**
 * Define an initializer which will execute a callback with a PluginApi object.
 *
 * @param {(api: import("discourse/lib/plugin-api").PluginApi, opts: object) => any} apiCodeCallback - The callback function to execute
 * @param {object} [opts] - Optional additional options to pass to the callback function.
 */
export function apiInitializer(apiCodeCallback, opts) {
  if (typeof arguments[0] === "string") {
    // Old path. First argument is the version string. Silently ignore.
    [, apiCodeCallback, opts] = arguments;
  }
  return {
    name: `api-initializer${_apiInitializerId++}`,
    after: "inject-objects",
    initialize() {
      return withPluginApi(apiCodeCallback, opts);
    },
  };
}
