// @ts-check
import { service } from "@ember/service";
import { findClosestMatch } from "discourse/lib/string-similarity";
import { BlockCondition } from "./condition";
import { blockCondition } from "./decorator";

/**
 * A condition that evaluates based on site setting or custom settings object values.
 *
 * Supports multiple condition types for different setting formats:
 * - `enabled` - For boolean settings (truthy/falsy check)
 * - `equals` - For exact value matching (strings, numbers, enums)
 * - `includes` - When setting is a single value: check if it matches one of YOUR provided options
 * - `contains` - When setting is a list: check if it contains YOUR single value
 * - `containsAny` - When setting is a list: check if it contains ANY of YOUR provided values
 *
 * **`includes` vs `contains` - Key Difference:**
 *
 * | Condition    | Setting type               | Question answered                        |
 * |--------------|----------------------------|------------------------------------------|
 * | `includes`   | Single value (enum/string) | Is the setting value IN my list?         |
 * | `contains`   | List (pipe-separated)      | Does the setting list CONTAIN my value?  |
 *
 * **Theme Settings Support:**
 * Pass a custom settings object via `source` (e.g., from `import { settings } from "virtual:theme"`)
 * to check theme-specific settings instead of site settings.
 *
 * **Note:** Setting name validation is deferred to evaluate time since it requires
 * access to the siteSettings service. Unknown settings will cause the condition to
 * return false rather than throw an error at registration time.
 *
 * @class BlockSettingCondition
 * @extends BlockCondition
 *
 * @param {string} name - The setting key to check (required).
 * @param {Object} [source] - Custom settings object (e.g., theme settings). If not provided, uses siteSettings.
 * @param {boolean} [enabled] - If true, passes when setting is truthy; if false, passes when falsy.
 * @param {*} [equals] - Passes when setting exactly equals this value.
 * @param {Array<*>} [includes] - For single-value settings: passes when setting value is in this array.
 * @param {string} [contains] - For list settings: passes when the setting list contains this value.
 * @param {Array<string>} [containsAny] - For list settings: passes when setting list contains ANY of these.
 *
 * @example
 * // Boolean setting check
 * { type: "setting", name: "enable_badges", enabled: true }
 *
 * @example
 * // Exact value match
 * { type: "setting", name: "desktop_category_page_style", equals: "categories_and_latest_topics" }
 *
 * @example
 * // Setting is one of several values
 * { type: "setting", name: "desktop_category_page_style", includes: ["categories_and_latest_topics", "categories_and_top_topics"] }
 *
 * @example
 * // List setting contains value
 * { type: "setting", name: "top_menu", contains: "hot" }
 *
 * @example
 * // List setting contains any of values
 * { type: "setting", name: "share_links", containsAny: ["twitter", "facebook"] }
 *
 * @example
 * // Theme setting check (pass settings object from "virtual:theme")
 * import { settings } from "virtual:theme";
 * { type: "setting", source: settings, name: "show_sidebar", enabled: true }
 */
@blockCondition({
  type: "setting",
  sourceType: "object",
  args: {
    name: { type: "string", required: true },
    enabled: { type: "boolean" },
    equals: {}, // any type allowed
    includes: { type: "array" },
    contains: { type: "string" },
    containsAny: { type: "array" },
  },
  constraints: {
    // At most one condition type allowed (0 is fine - defaults to truthy check)
    atMostOne: ["enabled", "equals", "includes", "contains", "containsAny"],
  },
  // No custom validate - setting name existence checked at evaluate time
  // (since it requires service access to siteSettings)
})
export default class BlockSettingCondition extends BlockCondition {
  @service siteSettings;

  /**
   * Evaluates whether the setting condition passes.
   *
   * @param {Object} args - The condition arguments.
   * @param {Object} [context] - Evaluation context.
   * @returns {boolean} True if the condition passes.
   */
  evaluate(args, context) {
    const { name, enabled, equals, includes, contains, containsAny } = args;

    // Determine settings source:
    // 1. If source is provided, use it (even if it resolves to null/undefined - no fallback)
    // 2. If source is NOT provided, use siteSettings
    const settingsSource =
      args.source !== undefined
        ? this.resolveSource(args, context)
        : this.siteSettings;

    // Handle null/undefined settings source gracefully
    if (settingsSource == null) {
      return false;
    }

    // Return false for unknown settings (deferred validation)
    if (!(name in settingsSource)) {
      return false;
    }

    const value = settingsSource?.[name];

    // Check enabled/disabled (boolean check)
    if (enabled !== undefined) {
      return enabled ? !!value : !value;
    }

    // Check exact equality
    if (equals !== undefined) {
      return value === equals;
    }

    // Check if value is in the includes array (for enum settings)
    if (includes?.length) {
      return includes.includes(value);
    }

    // Check if list setting contains a specific value
    if (contains !== undefined) {
      return this.#settingContains(value, contains);
    }

    // Check if list setting contains any of the provided values
    if (containsAny?.length) {
      return containsAny.some((item) => this.#settingContains(value, item));
    }

    // No condition specified, check if setting exists and is truthy
    return !!value;
  }

  /**
   * Checks if a list setting contains a specific value.
   * Handles both array and pipe-separated string formats.
   *
   * Values are converted to strings before comparison to handle cases where
   * `searchValue` might be a number but the setting stores string values
   * (e.g., checking for `123` in `"123|456"`).
   *
   * @param {string|Array} settingValue - The setting value (may be "a|b|c" or ["a", "b", "c"]).
   * @param {string|number} searchValue - The value to search for.
   * @returns {boolean} True if the setting contains the search value.
   */
  #settingContains(settingValue, searchValue) {
    if (Array.isArray(settingValue)) {
      // Convert all values to strings for consistent matching
      return settingValue.map(String).includes(String(searchValue));
    }

    if (typeof settingValue === "string") {
      // List settings are often pipe-separated strings like "latest|new|unread"
      const items = settingValue.split("|").map((s) => s.trim());
      return items.includes(String(searchValue));
    }

    return false;
  }

  /**
   * Returns the resolved setting value for debug logging.
   * Includes a warning note with "did you mean" suggestion if the setting doesn't exist.
   *
   * @param {Object} args - The condition arguments.
   * @param {Object} [context] - Evaluation context.
   * @returns {{ value: *, hasValue: true, note?: string }}
   */
  getResolvedValueForLogging(args, context) {
    const { name } = args;

    // Determine settings source (same logic as evaluate)
    const settingsSource =
      args.source !== undefined
        ? this.resolveSource(args, context)
        : this.siteSettings;

    // Handle null/undefined settings source
    if (settingsSource == null) {
      return {
        value: undefined,
        hasValue: true,
        note: "settings source is null/undefined",
      };
    }

    // Check if setting exists
    if (!(name in settingsSource)) {
      const availableSettings = Object.keys(settingsSource);
      const suggestion = findClosestMatch(name, availableSettings);
      const noteText = suggestion
        ? `"${name}" does not exist (did you mean "${suggestion}"?)`
        : `"${name}" does not exist`;

      return {
        value: undefined,
        hasValue: true,
        note: noteText,
      };
    }

    // Return the actual value
    return {
      value: settingsSource[name],
      hasValue: true,
    };
  }
}
