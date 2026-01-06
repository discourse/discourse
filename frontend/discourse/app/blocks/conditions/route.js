import { service } from "@ember/service";
import {
  getShortcutName,
  isShortcut,
  isValidUrlPattern,
  matchesAnyPattern,
  normalizePath,
  VALID_SHORTCUTS,
} from "discourse/lib/blocks/url-matcher";
import { matchParams } from "discourse/lib/blocks/value-matcher";
import { BlockCondition, raiseBlockValidationError } from "./base";

/**
 * A condition that evaluates based on the current URL path, semantic shortcuts,
 * route parameters, and query parameters.
 *
 * URL patterns use picomatch glob syntax:
 * - `*` matches a single path segment (no slashes)
 * - `**` matches zero or more path segments
 * - `?` matches a single character
 * - `[abc]` matches any character in the brackets
 * - `{a,b}` matches any of the comma-separated patterns
 *
 * Shortcuts (prefixed with `$`) match semantic page types without requiring
 * knowledge of URL structure:
 * - `$CATEGORY_PAGES` - any category page (when `discovery.category` is set)
 * - `$DISCOVERY_PAGES` - discovery routes (latest, top, etc.) excluding custom homepage
 * - `$HOMEPAGE` - custom homepage only
 * - `$TAG_PAGES` - any tag page (when `discovery.tag` is set)
 * - `$TOP_MENU` - discovery routes that appear in the top navigation menu
 *
 * URL matching automatically handles Discourse subfolder installations by
 * normalizing URLs before matching. Theme authors don't need to know if
 * Discourse runs on `/forum` or root - patterns like `/c/**` work everywhere.
 *
 * @class BlockRouteCondition
 * @extends BlockCondition
 *
 * @param {string[]} [urls] - URL patterns or shortcuts to match (passes if ANY match).
 * @param {string[]} [excludeUrls] - URL patterns or shortcuts to exclude (passes if NONE match).
 * @param {Object} [params] - Route parameters to match (from `router.currentRoute.params`).
 * @param {Object} [queryParams] - Query parameters to match (from `router.currentRoute.queryParams`).
 *
 * @example
 * // Match category pages using shortcut
 * { type: "route", urls: ["$CATEGORY_PAGES"] }
 *
 * @example
 * // Match category pages using URL pattern
 * { type: "route", urls: ["/c/**"] }
 *
 * @example
 * // Match multiple patterns (OR logic)
 * { type: "route", urls: ["$CATEGORY_PAGES", "/custom/**", "/tag/*"] }
 *
 * @example
 * // Match all except admin pages
 * { type: "route", excludeUrls: ["/admin/**"] }
 *
 * @example
 * // Match with query params
 * { type: "route", urls: ["/latest"], queryParams: { filter: "solved" } }
 *
 * @example
 * // Match discovery pages with specific query params using OR logic
 * { type: "route", urls: ["$DISCOVERY_PAGES"], queryParams: { any: [{ filter: "solved" }, { filter: "open" }] } }
 */
export default class BlockRouteCondition extends BlockCondition {
  static type = "route";

  @service router;
  @service discovery;

  /**
   * Returns the current URL path, normalized for matching.
   *
   * Normalization strips the subfolder prefix, query strings, hash fragments,
   * and trailing slashes. This allows patterns to work consistently regardless
   * of Discourse's installation configuration.
   *
   * @returns {string} The normalized URL path.
   */
  get currentPath() {
    return normalizePath(this.router.currentURL);
  }

  /**
   * Validates the route condition arguments.
   *
   * @param {Object} args - The condition arguments.
   * @throws {Error} If validation fails.
   */
  validate(args) {
    const { urls, excludeUrls } = args;

    if (!urls?.length && !excludeUrls?.length) {
      raiseBlockValidationError(
        "BlockRouteCondition: Must provide `urls` or `excludeUrls`."
      );
    }

    if (urls?.length && excludeUrls?.length) {
      raiseBlockValidationError(
        "BlockRouteCondition: Cannot use both `urls` and `excludeUrls`. Use one or the other."
      );
    }

    // Validate all shortcuts are recognized and glob patterns are valid
    const allPatterns = [...(urls || []), ...(excludeUrls || [])];
    for (const pattern of allPatterns) {
      if (isShortcut(pattern)) {
        const name = getShortcutName(pattern);
        if (!VALID_SHORTCUTS.includes(name)) {
          const validList = VALID_SHORTCUTS.map((s) => "$" + s).join(", ");
          raiseBlockValidationError(
            `BlockRouteCondition: Unknown shortcut "$${name}". ` +
              `Valid shortcuts: ${validList}`
          );
        }
      } else if (!isValidUrlPattern(pattern)) {
        // Validate glob pattern syntax (non-shortcuts only)
        raiseBlockValidationError(
          `BlockRouteCondition: Invalid glob pattern "${pattern}". ` +
            `Check for unbalanced brackets or braces.`
        );
      }
    }
  }

  /**
   * Evaluates whether the current route matches the condition.
   *
   * Evaluation logic:
   * - With `urls`: passes if ANY URL pattern OR shortcut matches
   * - With `excludeUrls`: passes if NO URL pattern AND NO shortcut matches
   * - With `params`: additionally requires all params to match
   * - With `queryParams`: additionally requires all query params to match
   *
   * @param {Object} args - The condition arguments.
   * @param {Object} [context={}] - Evaluation context (for debugging).
   * @returns {boolean} True if the condition passes.
   */
  evaluate(args, context = {}) {
    const { urls, excludeUrls, params, queryParams } = args;
    const currentPath = this.currentPath;

    // Debug context for nested logging
    const isDebugging = context.debug ?? false;
    const logger = context.logger;
    const childDepth = (context._depth ?? 0) + 1;
    const debugContext = { debug: isDebugging, _depth: childDepth, logger };

    // Get actual params for debugging output
    const actualParams = this.router.currentRoute?.params;
    const actualQueryParams = this.router.currentRoute?.queryParams;

    let routeMatched = true;

    // Check excludeUrls (passes if NONE match)
    if (excludeUrls?.length) {
      const patternMatch = matchesAnyPattern(currentPath, excludeUrls);
      const shortcutMatch = this.#matchesAnyShortcut(excludeUrls);

      if (patternMatch || shortcutMatch) {
        routeMatched = false;
      }
    }

    // Check urls (passes if ANY match)
    if (routeMatched && urls?.length) {
      const patternMatch = matchesAnyPattern(currentPath, urls);
      const shortcutMatch = this.#matchesAnyShortcut(urls);

      if (!patternMatch && !shortcutMatch) {
        routeMatched = false;
      }
    }

    // Log URL state when debugging (only when params/queryParams present)
    if (isDebugging && (params || queryParams)) {
      logger?.logRouteState?.({
        currentPath,
        expectedUrls: urls,
        excludeUrls,
        actualParams,
        actualQueryParams,
        depth: childDepth,
        result: routeMatched,
      });
    }

    // Return early if URL/shortcut didn't match
    if (!routeMatched) {
      return false;
    }

    // Check params (uses shared matcher with AND/OR/NOT support)
    if (params) {
      if (
        !matchParams({
          actualParams,
          expectedParams: params,
          context: debugContext,
          label: "params",
        })
      ) {
        return false;
      }
    }

    // Check query params (uses shared matcher with AND/OR/NOT support)
    if (queryParams) {
      if (
        !matchParams({
          actualParams: actualQueryParams,
          expectedParams: queryParams,
          context: debugContext,
          label: "queryParams",
        })
      ) {
        return false;
      }
    }

    return true;
  }

  /**
   * Checks if any shortcut in the patterns array matches the current route.
   *
   * @param {string[]} patterns - Array of patterns (filters to shortcuts only).
   * @returns {boolean} True if any shortcut matches.
   */
  #matchesAnyShortcut(patterns) {
    return patterns
      .filter((p) => isShortcut(p))
      .some((p) => this.#matchesShortcut(getShortcutName(p)));
  }

  /**
   * Evaluates a shortcut against the current discovery service state.
   *
   * Shortcuts provide semantic route matching based on page context rather than
   * URL patterns. This allows theme authors to target logical page types without
   * knowing the internal URL structure.
   *
   * @param {string} shortcut - The shortcut name (without $ prefix).
   * @returns {boolean} True if the current route matches the shortcut's criteria.
   */
  #matchesShortcut(shortcut) {
    switch (shortcut) {
      case "CATEGORY_PAGES":
        // True when viewing any category page
        return !!this.discovery.category;

      case "DISCOVERY_PAGES":
        // True on discovery routes (latest, top, new, etc.) excluding custom homepage
        return this.discovery.onDiscoveryRoute && !this.discovery.custom;

      case "HOMEPAGE":
        // True only on the custom homepage route
        return this.discovery.custom;

      case "TAG_PAGES":
        // True when viewing any tag page
        return !!this.discovery.tag;

      case "TOP_MENU":
        // True on discovery routes that appear in the top navigation menu
        // (excludes category pages, tag pages, and custom homepage)
        return (
          this.discovery.onDiscoveryRoute &&
          !this.discovery.category &&
          !this.discovery.tag &&
          !this.discovery.custom
        );

      default:
        // Unknown shortcuts never match (should be caught by validation)
        return false;
    }
  }
}
