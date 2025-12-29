import Component from "@glimmer/component";
import { DEBUG } from "@glimmer/env";
import { service } from "@ember/service";
import { block } from "discourse/components/block-outlet";

/**
 * A conditional container block that renders children based on site setting values.
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
 * | Condition | Setting type | Question answered |
 * |-----------|--------------|-------------------|
 * | `includes` | Single value (enum/string) | Is the setting value IN my list? |
 * | `contains` | List (pipe-separated) | Does the setting list CONTAIN my value? |
 *
 * Example with `includes` (setting holds ONE value, you provide MANY options):
 * - Setting `desktop_category_page_style` = `"categories_and_latest_topics"`
 * - `includes: ["categories_and_latest_topics", "categories_and_top_topics"]`
 * - Question: Is `"categories_and_latest_topics"` in my list? → YES
 *
 * Example with `contains` (setting holds MANY values, you look for ONE):
 * - Setting `top_menu` = `"latest|new|unread|hot|categories"`
 * - `contains: "hot"`
 * - Question: Does the menu list contain `"hot"`? → YES
 *
 * **Important:** Only one condition type should be used per instance.
 *
 * @component SiteSettingCondition
 * @param {string} setting - The site setting name to check (required, must have `client: true`)
 * @param {boolean} [enabled] - If true, render when setting is truthy; if false, render when falsy
 * @param {*} [equals] - Render when setting exactly equals this value
 * @param {Array<*>} [includes] - For single-value settings: render when setting value is in this array
 * @param {string} [contains] - For list settings: render when the setting list contains this value
 * @param {Array<string>} [containsAny] - For list settings: render when setting list contains ANY of these
 *
 * @example
 * // Render only when badges are enabled (boolean setting)
 * {
 *   block: SiteSettingCondition,
 *   args: { setting: "enable_badges", enabled: true },
 *   children: [
 *     { block: BlockBadgeShowcase }
 *   ]
 * }
 *
 * @example
 * // Render when Google OAuth is NOT enabled (check disabled state)
 * {
 *   block: SiteSettingCondition,
 *   args: { setting: "enable_google_oauth2_logins", enabled: false },
 *   children: [
 *     { block: BlockAlternativeLoginOptions }
 *   ]
 * }
 *
 * @example
 * // Render based on category page style (enum setting, exact match)
 * {
 *   block: SiteSettingCondition,
 *   args: { setting: "desktop_category_page_style", equals: "categories_and_latest_topics" },
 *   children: [
 *     { block: BlockCategoryLatestEnhancement }
 *   ]
 * }
 *
 * @example
 * // `includes`: Setting is ONE value, check if it's in YOUR list of acceptable values
 * // desktop_category_page_style = "categories_and_latest_topics"
 * // Is "categories_and_latest_topics" IN ["categories_and_latest_topics", "categories_and_top_topics"]?
 * {
 *   block: SiteSettingCondition,
 *   args: {
 *     setting: "desktop_category_page_style",
 *     includes: ["categories_and_latest_topics", "categories_and_top_topics"]
 *   },
 *   children: [
 *     { block: BlockCategorySidebar }
 *   ]
 * }
 *
 * @example
 * // `contains`: Setting is a LIST, check if it CONTAINS your value
 * // top_menu = "latest|new|unread|hot|categories"
 * // Does "latest|new|unread|hot|categories" CONTAIN "hot"?
 * {
 *   block: SiteSettingCondition,
 *   args: { setting: "top_menu", contains: "hot" },
 *   children: [
 *     { block: BlockHotTopicsWidget }
 *   ]
 * }
 *
 * @example
 * // `containsAny`: Setting is a LIST, check if it contains ANY of your values
 * // share_links = "twitter|facebook|email"
 * // Does it contain "twitter" OR "facebook"?
 * {
 *   block: SiteSettingCondition,
 *   args: { setting: "share_links", containsAny: ["twitter", "facebook"] },
 *   children: [
 *     { block: BlockSocialPromo }
 *   ]
 * }
 */
@block("site-setting-condition", { container: true })
export default class SiteSettingCondition extends Component {
  @service siteSettings;

  constructor() {
    super(...arguments);
    this.#validateArgs();
  }

  get shouldRender() {
    const { setting, enabled, equals, includes, contains, containsAny } =
      this.args;
    const value = this.siteSettings[setting];

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
   * @param {string|Array} settingValue - The setting value (may be "a|b|c" or ["a", "b", "c"])
   * @param {string} searchValue - The value to search for
   * @returns {boolean}
   */
  #settingContains(settingValue, searchValue) {
    if (Array.isArray(settingValue)) {
      return settingValue.includes(searchValue);
    }

    if (typeof settingValue === "string") {
      // List settings are often pipe-separated strings like "latest|new|unread"
      const items = settingValue.split("|").map((s) => s.trim());
      return items.includes(searchValue);
    }

    return false;
  }

  #validateArgs() {
    const { setting, enabled, equals, includes, contains, containsAny } =
      this.args;

    if (!setting) {
      this.#reportError(
        "SiteSettingCondition: `setting` argument is required."
      );
      return;
    }

    // Check that setting exists (only client: true settings are available)
    if (!(setting in this.siteSettings)) {
      this.#reportError(
        `SiteSettingCondition: Unknown site setting "${setting}". ` +
          `Ensure the setting name is correct and has \`client: true\` in site_settings.yml.`
      );
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
      this.#reportError(
        "SiteSettingCondition: Cannot use multiple condition types together. " +
          "Use only one of: `enabled`, `equals`, `includes`, `contains`, or `containsAny`."
      );
    }
  }

  #reportError(message) {
    if (DEBUG) {
      throw new Error(message);
    } else {
      // eslint-disable-next-line no-console
      console.warn(message);
    }
  }

  <template>
    {{#if this.shouldRender}}
      {{#each this.children as |child|}}
        <child.Component @outletName={{@outletName}} />
      {{/each}}
    {{/if}}
  </template>
}
