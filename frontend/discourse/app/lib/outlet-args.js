/**
 * Shared utilities for outlet args with deprecation support.
 *
 * These utilities are used by both PluginOutlet and BlockOutlet to handle
 * deprecated args with lazy evaluation and warning messages.
 *
 * @module discourse/lib/outlet-args
 */

import { isDeprecatedOutletArgument } from "discourse/helpers/deprecated-outlet-argument";
import deprecated, { withSilencedDeprecations } from "discourse/lib/deprecated";

/**
 * Symbol used to store the raw deprecatedArgs object as a non-enumerable
 * property on the combined args object. This is used by dev-tools to display
 * deprecation info without triggering the deprecation warnings.
 */
export const DEPRECATED_ARGS_KEY = "__deprecatedArgs__";

/**
 * Flag to control whether buildArgsWithDeprecations includes the raw
 * deprecatedArgs object as a non-enumerable property. This is enabled
 * by dev-tools when outlet debugging is active.
 */
let _includeDeprecatedArgsProperty = false;

/**
 * Enables or disables including the raw deprecatedArgs object as a
 * non-enumerable property in buildArgsWithDeprecations output.
 *
 * @param {boolean} value - Whether to include the property.
 */
export function _setIncludeDeprecatedArgsProperty(value) {
  _includeDeprecatedArgsProperty = value;
}

/**
 * Builds an args object that combines current args with deprecated args.
 *
 * Both current and deprecated args are accessed via property getters for lazy
 * evaluation. Deprecated args trigger a deprecation warning when accessed.
 *
 * @param {Object} args - Current outlet args.
 * @param {Object} deprecatedArgs - Deprecated args created with `deprecatedOutletArgument` helper.
 * @param {Object} [opts={}] - Options passed to deprecation warnings.
 * @param {string} [opts.outletName] - The outlet name for warning messages.
 * @returns {Object} Combined args object with lazy property getters.
 *
 * @example
 * const argsWithDeprecations = buildArgsWithDeprecations(
 *   { topic: this.topic },
 *   { oldTopic: deprecatedOutletArgument({ value: this.topic, message: "Use 'topic'" }) },
 *   { outletName: "topic-sidebar" }
 * );
 */
export function buildArgsWithDeprecations(args, deprecatedArgs, opts = {}) {
  const output = {};

  if (args) {
    Object.keys(args).forEach((key) => {
      Object.defineProperty(output, key, {
        enumerable: true,
        get() {
          return args[key];
        },
      });
    });
  }

  if (deprecatedArgs) {
    Object.keys(deprecatedArgs).forEach((argumentName) => {
      // Skip if this key already exists in args (e.g., from a parent outlet's
      // outletArgsWithDeprecations that already includes deprecatedArgs)
      if (args && argumentName in args) {
        return;
      }

      Object.defineProperty(output, argumentName, {
        enumerable: true,
        get() {
          const deprecatedArg = deprecatedArgs[argumentName];

          return deprecatedArgumentValue(deprecatedArg, {
            ...opts,
            argumentName,
          });
        },
      });
    });

    // When dev-tools outlet debugging is enabled, include the raw deprecatedArgs
    // as a non-enumerable property so ArgsTable can display deprecation info.
    if (_includeDeprecatedArgsProperty) {
      Object.defineProperty(output, DEPRECATED_ARGS_KEY, {
        enumerable: false,
        value: deprecatedArgs,
      });
    }
  }

  return output;
}

/**
 * Evaluates a deprecated argument, triggering a deprecation warning.
 *
 * The warning is triggered each time the value is accessed. If the deprecated
 * arg has a `silence` option, the warning is silenced under that deprecation ID.
 *
 * @param {Object} deprecatedArg - A deprecated arg created with `deprecatedOutletArgument` helper.
 * @param {Object} options - Options for the deprecation warning.
 * @param {string} options.argumentName - The name of the deprecated arg.
 * @param {string} [options.outletName] - The outlet name for the warning message.
 * @param {string} [options.classModuleName] - Module name for connector class.
 * @param {string} [options.templateModule] - Module name for connector template.
 * @param {string} [options.connectorName] - Connector name.
 * @param {string} [options.layoutName] - Layout name.
 * @returns {*} The value of the deprecated arg.
 * @throws {Error} If the deprecated arg was not created with `deprecatedOutletArgument`.
 */
export function deprecatedArgumentValue(deprecatedArg, options) {
  if (!isDeprecatedOutletArgument(deprecatedArg)) {
    throw new Error(
      "deprecated argument is not defined properly, use helper `deprecatedOutletArgument` from discourse/helpers/deprecated-outlet-argument"
    );
  }

  let message = deprecatedArg.message;
  if (!message) {
    if (options.outletName) {
      message = `outlet arg \`${options.argumentName}\` is deprecated on the outlet \`${options.outletName}\``;
    } else {
      message = `${options.argumentName} is deprecated`;
    }
  }

  const connectorModule =
    options.classModuleName || options.templateModule || options.connectorName;

  if (connectorModule) {
    message += ` [used on connector ${connectorModule}]`;
  } else if (options.layoutName) {
    message += ` [used on ${options.layoutName}]`;
  }

  if (!deprecatedArg.silence) {
    deprecated(message, deprecatedArg.options);
    return deprecatedArg.value;
  }

  return withSilencedDeprecations(deprecatedArg.silence, () => {
    deprecated(message, deprecatedArg.options);
    return deprecatedArg.value;
  });
}
