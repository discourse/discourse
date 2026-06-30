// @ts-check
import { splitSourceArgs } from "discourse/lib/customization-source";
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
  // calls made from plugin/theme code; splitSourceArgs strips it (and any legacy
  // version string) so it can be forwarded to `withPluginApi`.
  let source;
  ({ apiCodeCallback, opts, source } = splitSourceArgs(Array.from(arguments)));

  return {
    name: `api-initializer${_apiInitializerId++}`,
    after: "inject-objects",
    initialize() {
      // A trailing undefined source is harmless: withPluginApi only treats a
      // branded descriptor as the source.
      return withPluginApi(apiCodeCallback, opts, source);
    },
  };
}
