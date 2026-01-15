// @ts-check
import { service } from "@ember/service";
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
  validArgKeys: [
    "name",
    "enabled",
    "equals",
    "includes",
    "contains",
    "containsAny",
  ],
})
export default class BlockSettingCondition extends BlockCondition {
  @service siteSettings;

  validate(args) {
    // Check base class validation (source parameter)
    const baseError = super.validate(args);
    if (baseError) {
      return baseError;
    }

    const { name, source, enabled, equals, includes, contains, containsAny } =
      args;

    if (!name) {
      return {
        message: "`name` argument is required.",
        path: "name",
      };
    }

    if (typeof name !== "string") {
      return {
        message: "`name` argument must be a string.",
        path: "name",
      };
    }

    // Skip site settings check if custom settings object is provided via source
    // (e.g., theme settings from "virtual:theme")
    if (!source && !(name in this.siteSettings)) {
      return {
        message:
          `Unknown site setting "${name}". ` +
          `Ensure the setting name is correct and has \`client: true\` in site_settings.yml.`,
        path: "name",
      };
    }

    // Check for conflicting conditions
    const conditionCount = [
      enabled !== undefined,
      equals !== undefined,
      includes?.length > 0,
      contains !== undefined,
      containsAny?.length > 0,
    ].filter(Boolean).length;

    if (conditionCount > 1) {
      return {
        message:
          "Cannot use multiple condition types together. " +
          "Use only one of: `enabled`, `equals`, `includes`, `contains`, or `containsAny`.",
      };
    }

    return null;
  }

  evaluate(args, context) {
    const { name, enabled, equals, includes, contains, containsAny } = args;

    // Determine settings source:
    // 1. If source is provided, use it (even if it resolves to null/undefined - no fallback)
    // 2. If source is NOT provided, use siteSettings
    const settingsSource =
      args.source !== undefined
        ? this.resolveSource(args, context)
        : this.siteSettings;
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
}
