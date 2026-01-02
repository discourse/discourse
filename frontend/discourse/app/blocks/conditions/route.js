import { service } from "@ember/service";
import { blockDebugLogger } from "discourse/lib/blocks/debug-logger";
import { matchParams } from "discourse/lib/blocks/value-matcher";
import { BlockCondition, raiseBlockValidationError } from "./base";

/**
 * Route shortcut symbols for common route conditions.
 * Use these with BlockRouteCondition's `routes` or `excludeRoutes` args.
 *
 * @property {Symbol} CATEGORY_PAGES - Any category route
 * @property {Symbol} DISCOVERY_PAGES - Any discovery route (latest, top, etc.) excluding custom homepage
 * @property {Symbol} HOMEPAGE - Custom homepage route only
 * @property {Symbol} TAG_PAGES - Any tag route
 * @property {Symbol} TOP_MENU - Discovery routes excluding category, tag, and custom homepage
 */
export const BlockRouteConditionShortcuts = Object.freeze({
  CATEGORY_PAGES: Symbol("CATEGORY_PAGES"),
  DISCOVERY_PAGES: Symbol("DISCOVERY_PAGES"),
  HOMEPAGE: Symbol("HOMEPAGE"),
  TAG_PAGES: Symbol("TAG_PAGES"),
  TOP_MENU: Symbol("TOP_MENU"),
});

/**
 * A condition that evaluates based on the current route, route parameters, and query parameters.
 *
 * Route patterns support:
 * - Exact match: `"discovery.latest"`
 * - Wildcard suffix: `"category.*"` matches `"category.none"`, `"category.all"`, etc.
 * - Regular expression: `/^topic\.\d+$/` for advanced matching
 * - Route shortcuts: `BlockRouteConditionShortcuts.DISCOVERY_PAGES`, `BlockRouteConditionShortcuts.HOMEPAGE`, etc.
 *
 * When using `routes`, the condition passes if the current route matches ANY pattern (OR logic).
 * When using `excludeRoutes`, the condition passes if the current route matches NONE of the patterns.
 *
 * Params and queryParams support AND/OR/NOT logic:
 * - Object with keys: AND logic (all keys must match)
 * - `{ any: [...] }`: OR logic (any must match)
 * - `{ not: {...} }`: NOT logic (must NOT match)
 * - Keys starting with `\` are escaped (e.g., `"\\any"` matches literal param `"any"`)
 *
 * @class BlockRouteCondition
 * @extends BlockCondition
 *
 * @param {Array<string|RegExp|Symbol>} [routes] - Route patterns to match (passes if ANY match).
 * @param {Array<string|RegExp|Symbol>} [excludeRoutes] - Route patterns to exclude (passes if NONE match).
 * @param {Object} [params] - Route parameters to match (from `router.currentRoute.params`).
 * @param {Object} [queryParams] - Query parameters to match (from `router.currentRoute.queryParams`).
 *
 * @example
 * // Match specific routes
 * { type: "route", routes: ["discovery.latest", "discovery.top"] }
 *
 * @example
 * // Match with wildcard
 * { type: "route", routes: ["category.*"] }
 *
 * @example
 * // Match with shortcut
 * { type: "route", routes: [BlockRouteConditionShortcuts.DISCOVERY_PAGES] }
 *
 * @example
 * // Exclude routes
 * { type: "route", excludeRoutes: ["discovery.custom"] }
 *
 * @example
 * // Match route with specific params
 * { type: "route", routes: ["topic.show"], params: { id: 123 } }
 *
 * @example
 * // Match route with query params
 * { type: "route", routes: ["discovery.latest"], queryParams: { filter: "solved" } }
 *
 * @example
 * // Match with OR logic on params
 * { type: "route", routes: ["topic.show"], params: { any: [{ id: 123 }, { slug: /^help-/ }] } }
 */
export default class BlockRouteCondition extends BlockCondition {
  static type = "route";

  @service router;
  @service discovery;

  validate(args) {
    const { routes, excludeRoutes } = args;

    if (routes?.length && excludeRoutes?.length) {
      raiseBlockValidationError(
        "BlockRouteCondition: Cannot use both `routes` and `excludeRoutes` arguments. Use one or the other."
      );
    }

    if (!routes?.length && !excludeRoutes?.length) {
      raiseBlockValidationError(
        "BlockRouteCondition: Must provide either `routes` or `excludeRoutes` argument."
      );
    }
  }

  evaluate(args, context = {}) {
    const currentRoute = this.router.currentRouteName;

    if (!currentRoute) {
      return false;
    }

    const { routes, excludeRoutes, params, queryParams } = args;

    // Debug context for params matching - nested under route condition
    const isDebugging = context.debug ?? blockDebugLogger.hasActiveGroup();
    const childDepth = (context._depth ?? 0) + 1;
    const debugContext = { debug: isDebugging, _depth: childDepth };

    // Get actual params/queryParams for debug output
    const actualParams = this.router.currentRoute?.params;
    const actualQueryParams = this.router.currentRoute?.queryParams;

    // Check route matching BEFORE logging so we can show the correct icon
    // Check excludeRoutes first (passes if NONE match)
    let routeMatched = true;
    if (excludeRoutes?.length) {
      if (this.#matchesAny(currentRoute, excludeRoutes)) {
        routeMatched = false;
      }
    }

    // Check routes (passes if ANY match)
    if (routeMatched && routes?.length) {
      if (!this.#matchesAny(currentRoute, routes)) {
        routeMatched = false;
      }
    }

    // Log current route state when debugging (always log if debugging, so users
    // can see the current route even when it doesn't match)
    if (isDebugging && (params || queryParams)) {
      blockDebugLogger.logRouteState({
        currentRoute,
        expectedRoutes: routes,
        excludeRoutes,
        actualParams,
        actualQueryParams,
        depth: childDepth,
        result: routeMatched,
      });
    }

    // Return early if route didn't match
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

  #matchesAny(currentRoute, patterns) {
    return patterns.some((pattern) =>
      this.#matchesPattern(currentRoute, pattern)
    );
  }

  /**
   * Checks if a route matches a given pattern. Supports four pattern types:
   *
   * 1. **Symbol shortcuts** - Predefined shortcuts like `CATEGORY_PAGES` that match
   *    multiple related routes.
   * 2. **RegExp** - Regular expression for advanced pattern matching.
   * 3. **Wildcard** - String ending with `.*` that matches any route with that prefix
   *    (e.g., `"category.*"` matches `"category"`, `"category.none"`, `"category.all"`).
   * 4. **Exact match** - String that must match the route name exactly.
   *
   * @param {string} route - The current route name to test.
   * @param {string|RegExp|Symbol} pattern - The pattern to match against.
   * @returns {boolean} True if the route matches the pattern.
   */
  #matchesPattern(route, pattern) {
    // Symbol shortcut pattern (e.g., BlockRouteConditionShortcuts.CATEGORY_PAGES)
    if (typeof pattern === "symbol") {
      return this.#matchesShortcut(pattern);
    }

    // RegExp pattern for advanced matching (e.g., /^topic\.\d+$/)
    if (pattern instanceof RegExp) {
      return pattern.test(route);
    }

    // Wildcard pattern: "category.*" matches "category", "category.none", "category.all", etc.
    // This provides glob-style matching for route hierarchies.
    if (pattern.endsWith(".*")) {
      const prefix = pattern.slice(0, -2);
      return route === prefix || route.startsWith(`${prefix}.`);
    }

    // Exact match: route name must equal the pattern string exactly
    return route === pattern;
  }

  /**
   * Evaluates a route shortcut symbol against the current discovery service state.
   * Shortcuts provide semantic route matching based on page context rather than
   * route name patterns.
   *
   * - `CATEGORY_PAGES` - True when viewing any category (category is set).
   * - `DISCOVERY_PAGES` - True on discovery routes (latest, top, etc.) but NOT on
   *   custom homepage.
   * - `HOMEPAGE` - True only on the custom homepage route.
   * - `TAG_PAGES` - True when viewing any tag page (tag is set).
   * - `TOP_MENU` - True on discovery routes excluding category, tag, and custom
   *   homepage (i.e., the main navigation menu items).
   *
   * @param {Symbol} shortcut - A symbol from BlockRouteConditionShortcuts.
   * @returns {boolean} True if the current route matches the shortcut's criteria.
   */
  #matchesShortcut(shortcut) {
    switch (shortcut) {
      case BlockRouteConditionShortcuts.CATEGORY_PAGES:
        // True when viewing any category page
        return !!this.discovery.category;

      case BlockRouteConditionShortcuts.DISCOVERY_PAGES:
        // True on discovery routes (latest, top, new, etc.) excluding custom homepage
        return this.discovery.onDiscoveryRoute && !this.discovery.custom;

      case BlockRouteConditionShortcuts.HOMEPAGE:
        // True only on the custom homepage route
        return this.discovery.custom;

      case BlockRouteConditionShortcuts.TAG_PAGES:
        // True when viewing any tag page
        return !!this.discovery.tag;

      case BlockRouteConditionShortcuts.TOP_MENU:
        // True on discovery routes that appear in the top navigation menu
        // (excludes category pages, tag pages, and custom homepage)
        return (
          this.discovery.onDiscoveryRoute &&
          !this.discovery.category &&
          !this.discovery.tag &&
          !this.discovery.custom
        );

      default:
        // Unknown shortcuts never match
        return false;
    }
  }
}
