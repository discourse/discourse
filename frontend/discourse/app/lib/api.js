// @ts-check
import { isCustomizationSource } from "discourse/lib/customization-source";
import { withPluginApi } from "discourse/lib/plugin-api";

let _apiInitializerId = 0;

/**
 * Define an initializer which will execute a callback with a PluginApi object.
 *
 * @param {(api: import("./plugin-api.gjs").PluginApi, opts: object) => any} apiCodeCallback - The callback function to execute
 * @param {object} [opts] - Optional additional options to pass to the callback function.
 */
export function apiInitializer(apiCodeCallback, opts) {
  // The asset processor appends a branded customization-source descriptor to
  // calls made from plugin/theme code; forward it to `withPluginApi` so the
  // api handed to the callback knows its origin.
  let args = Array.from(arguments);
  let source;
  if (args.length > 0 && isCustomizationSource(args[args.length - 1])) {
    source = args.pop();
  }

  if (typeof args[0] === "string") {
    // Old path. First argument is the version string. Silently ignore.
    args = args.slice(1);
  }

  apiCodeCallback = args[0];
  opts = args[1];

  return {
    name: `api-initializer${_apiInitializerId++}`,
    after: "inject-objects",
    initialize() {
      return source === undefined
        ? withPluginApi(apiCodeCallback, opts)
        : withPluginApi(apiCodeCallback, opts, source);
    },
  };
}
