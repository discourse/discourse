import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { isDeprecatedOutletArgument } from "discourse/helpers/deprecated-outlet-argument";
import { DEPRECATED_ARGS_KEY } from "discourse/lib/outlet-args";
import { logArgToConsole } from "../lib/console-logger";
import { formatValue, getTypeInfo } from "../lib/value-formatter";

/**
 * Shared component for displaying outlet arguments in a formatted table.
 * Used by both PluginOutlet and BlockOutlet debug tooltips.
 *
 * Supports deprecated arguments marked with the `deprecatedOutletArgument` helper,
 * showing a visual indicator and deprecation info. Deprecated args are read from
 * `args.__deprecatedArgs__` (set by `buildArgsWithDeprecations` when dev-tools outlet
 * debugging is enabled).
 *
 * @param {Object} args - The arguments to display. May contain a non-enumerable
 *   `__deprecatedArgs__` property with the raw deprecated args.
 * @param {string} [prefix] - Prefix for console logging context (e.g., "plugin outlet").
 */
export default class ArgsTable extends Component {
  /**
   * Transforms the raw args object into an array of entry objects for display.
   * Each entry contains the original key/value plus formatted display representations.
   *
   * @returns {Array<{key: string, value: any, displayValue: string, typeInfo: string, isDeprecated: boolean, deprecationInfo: Object|null}>}
   */
  get entries() {
    const entries = [];
    const args = this.args.args;

    // Read deprecatedArgs from the non-enumerable property on args (set by
    // buildArgsWithDeprecations when dev-tools outlet debugging is enabled).
    const deprecatedArgs = args?.[DEPRECATED_ARGS_KEY];

    const deprecatedKeys = new Set(
      deprecatedArgs && typeof deprecatedArgs === "object"
        ? Object.keys(deprecatedArgs)
        : []
    );

    // Process regular args first, but skip keys that are in deprecatedArgs
    // (those will be handled in the second loop with proper deprecation info)
    if (args && typeof args === "object") {
      for (const [key, rawValue] of Object.entries(args)) {
        // Skip if this key exists in deprecatedArgs - it will be processed below
        if (deprecatedKeys.has(key)) {
          continue;
        }

        // Check if this is a deprecated arg that was merged into args
        const isDeprecated = isDeprecatedOutletArgument(rawValue);
        const value = isDeprecated ? rawValue.value : rawValue;

        entries.push({
          key,
          value,
          displayValue: formatValue(value),
          typeInfo: getTypeInfo(value),
          isDeprecated,
          deprecationInfo: isDeprecated
            ? this.#getDeprecationInfo(rawValue)
            : null,
        });
      }
    }

    // Process deprecated args (if passed separately)
    if (deprecatedArgs && typeof deprecatedArgs === "object") {
      for (const [key, deprecatedArg] of Object.entries(deprecatedArgs)) {
        if (isDeprecatedOutletArgument(deprecatedArg)) {
          const value = deprecatedArg.value;
          entries.push({
            key,
            value,
            displayValue: formatValue(value),
            typeInfo: getTypeInfo(value),
            isDeprecated: true,
            deprecationInfo: this.#getDeprecationInfo(deprecatedArg),
          });
        }
      }
    }

    return entries;
  }

  /**
   * Extracts deprecation info from a deprecated argument for display.
   *
   * @param {DeprecatedOutletArgument} deprecatedArg - The deprecated argument.
   * @returns {{message: string, since: string|undefined, dropFrom: string|undefined}}
   */
  #getDeprecationInfo(deprecatedArg) {
    return {
      message: deprecatedArg.message,
      since: deprecatedArg.options?.since,
      dropFrom: deprecatedArg.options?.dropFrom,
    };
  }

  /**
   * Logs the argument value to the console and stores it in a global variable
   * for easy inspection. The variable is named `arg1`, `arg2`, etc.
   *
   * @param {{key: string, value: any}} entry - The entry to log.
   */
  @action
  logValue(entry) {
    logArgToConsole({
      key: entry.key,
      value: entry.value,
      prefix: this.args.prefix,
    });
  }

  <template>
    {{#if this.entries.length}}
      <div class="outlet-args-table">
        {{#each this.entries as |entry|}}
          <button
            type="button"
            class={{concatClass
              "outlet-args-table__row"
              (if entry.isDeprecated "--deprecated")
            }}
            title={{if
              entry.isDeprecated
              entry.deprecationInfo.message
              "Save to global variable"
            }}
            {{on "click" (fn this.logValue entry)}}
          >
            <span class="outlet-args-table__key">
              @{{entry.key}}
              {{#if entry.isDeprecated}}
                <span class="outlet-args-table__deprecated-badge">
                  {{icon "triangle-exclamation"}}
                </span>
              {{/if}}
            </span>
            <span class="outlet-args-table__value">
              <span class="outlet-args-table__type">{{entry.typeInfo}}</span>
              {{entry.displayValue}}
            </span>
          </button>
          {{#if entry.isDeprecated}}
            <div class="outlet-args-table__deprecation-info">
              {{#if entry.deprecationInfo.message}}
                {{entry.deprecationInfo.message}}
              {{else}}
                Deprecated
              {{/if}}
              {{#if entry.deprecationInfo.since}}
                <span class="outlet-args-table__deprecation-version">
                  (since
                  {{entry.deprecationInfo.since}}{{#if
                    entry.deprecationInfo.dropFrom
                  }}, removal in {{entry.deprecationInfo.dropFrom}}{{/if}})
                </span>
              {{/if}}
            </div>
          {{/if}}
        {{/each}}
      </div>
    {{else}}
      <div class="outlet-args-table --empty">No arguments</div>
    {{/if}}
  </template>
}
