import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";

/**
 * Displays block arguments in a formatted table.
 * Similar to plugin-outlet-debug args-table.
 *
 * @component ArgsTable
 * @param {Object} args - The arguments to display
 */
export default class ArgsTable extends Component {
  #logCounter = 0;

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

  #formatValue(value) {
    if (value === null) {
      return "null";
    }
    if (value === undefined) {
      return "undefined";
    }
    if (typeof value === "string") {
      return `"${value.length > 50 ? value.slice(0, 50) + "..." : value}"`;
    }
    if (typeof value === "number" || typeof value === "boolean") {
      return String(value);
    }
    if (Array.isArray(value)) {
      return `Array(${value.length})`;
    }
    if (typeof value === "function") {
      return `fn ${value.name || "anonymous"}()`;
    }
    if (typeof value === "object") {
      const name = value.constructor?.name;
      if (name && name !== "Object") {
        return `${name} {...}`;
      }
      return "{...}";
    }
    return String(value);
  }

  #getTypeInfo(value) {
    if (value === null) {
      return "null";
    }
    if (value === undefined) {
      return "undefined";
    }
    if (Array.isArray(value)) {
      return "array";
    }
    return typeof value;
  }

  @action
  logValue(entry) {
    const varName = `arg${this.#logCounter++}`;
    window[varName] = entry.value;
    // eslint-disable-next-line no-console
    console.log(
      `%c${varName}%c = %c${entry.key}%c`,
      "color: #9c27b0; font-weight: bold",
      "",
      "color: #2196f3",
      "",
      entry.value
    );
  }

  <template>
    {{#if this.entries.length}}
      <div class="block-debug-args">
        {{#each this.entries as |entry|}}
          <button
            type="button"
            class="block-debug-args__row"
            title="Click to log to console"
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
