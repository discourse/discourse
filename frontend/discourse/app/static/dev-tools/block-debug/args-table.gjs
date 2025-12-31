import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { logArgToConsole } from "../lib/console-logger";

/**
 * Displays block arguments in a formatted table.
 * Similar to plugin-outlet-debug args-table.
 *
 * @component ArgsTable
 * @param {Object} args - The arguments to display
 */
export default class ArgsTable extends Component {
  /**
   * Transforms the raw args object into an array of entry objects for display.
   * Each entry contains the original key/value plus formatted display representations.
   *
   * @returns {Array<{key: string, value: any, displayValue: string, typeInfo: string}>}
   */
  get entries() {
    const args = this.args.args;
    if (!args || typeof args !== "object") {
      return [];
    }
    return Object.entries(args).map(([key, value]) => ({
      key,
      value,
      displayValue: this.#formatValue(value),
      typeInfo: this.#getTypeInfo(value),
    }));
  }

  /**
   * Formats a value for display in the debug table. Each type is handled differently
   * to provide a concise yet informative representation that fits in the UI.
   *
   * @param {any} value - The value to format.
   * @returns {string} A human-readable string representation of the value.
   */
  #formatValue(value) {
    // Null and undefined are displayed as literal keywords
    if (value === null) {
      return "null";
    }
    if (value === undefined) {
      return "undefined";
    }

    // Strings are quoted and truncated to prevent UI overflow
    if (typeof value === "string") {
      return `"${value.length > 50 ? value.slice(0, 50) + "..." : value}"`;
    }

    // Numbers and booleans can be displayed directly as their string representation
    if (typeof value === "number" || typeof value === "boolean") {
      return String(value);
    }

    // Arrays show their length since contents may be large
    if (Array.isArray(value)) {
      return `Array(${value.length})`;
    }

    // Functions show their name to help identify callbacks
    if (typeof value === "function") {
      return `fn ${value.name || "anonymous"}()`;
    }

    // Objects show their constructor name (e.g., "User {...}") or just "{...}"
    if (typeof value === "object") {
      const name = value.constructor?.name;
      if (name && name !== "Object") {
        return `${name} {...}`;
      }
      return "{...}";
    }

    // Fallback for any other types (symbols, bigints, etc.)
    return String(value);
  }

  /**
   * Determines the type label to display for a value. This provides a quick
   * visual indicator of what kind of data is in each argument.
   *
   * @param {any} value - The value to get the type info for.
   * @returns {string} A type label (e.g., "string", "number", "array", "object").
   */
  #getTypeInfo(value) {
    if (value === null) {
      return "null";
    }
    if (value === undefined) {
      return "undefined";
    }
    // Arrays are identified separately since typeof returns "object" for arrays
    if (Array.isArray(value)) {
      return "array";
    }
    return typeof value;
  }

  /**
   * Logs the argument value to the console and stores it in a global variable
   * for easy inspection. The variable is named `arg1`, `arg2`, etc.
   *
   * @param {{key: string, value: any}} entry - The entry to log.
   */
  @action
  logValue(entry) {
    logArgToConsole({ key: entry.key, value: entry.value });
  }

  <template>
    {{#if this.entries.length}}
      <div class="block-debug-args">
        {{#each this.entries as |entry|}}
          <button
            type="button"
            class="block-debug-args__row"
            title="Save to global variable"
            {{on "click" (fn this.logValue entry)}}
          >
            <span class="block-debug-args__key">{{entry.key}}</span>
            <span class="block-debug-args__value">
              <span class="block-debug-args__type">{{entry.typeInfo}}</span>
              {{entry.displayValue}}
            </span>
          </button>
        {{/each}}
      </div>
    {{else}}
      <div class="block-debug-args --empty">No arguments</div>
    {{/if}}
  </template>
}
