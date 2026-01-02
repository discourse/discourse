import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { logArgToConsole } from "../lib/console-logger";
import { formatValue, getTypeInfo } from "../lib/value-formatter";

/**
 * Displays plugin outlet arguments in a formatted table.
 * Similar to block-debug args-table but with plugin outlet context prefix.
 *
 * @component ArgsTable
 * @param {Object} outletArgs - The outlet arguments to display.
 */
export default class ArgsTable extends Component {
  /**
   * Transforms the raw outletArgs object into an array of entry objects for display.
   * Each entry contains the original key/value plus formatted display representations.
   *
   * @returns {Array<{key: string, value: any, displayValue: string, typeInfo: string}>}
   */
  get entries() {
    const args = this.args.outletArgs;
    if (!args || typeof args !== "object") {
      return [];
    }
    return Object.entries(args).map(([key, value]) => ({
      key,
      value,
      displayValue: formatValue(value),
      typeInfo: getTypeInfo(value),
    }));
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
      prefix: "plugin outlet",
    });
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
            <span class="block-debug-args__key">@{{entry.key}}</span>
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
