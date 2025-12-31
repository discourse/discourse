import { service } from "@ember/service";
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
 * A condition that evaluates based on the current route.
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
 * @class BlockRouteCondition
 * @extends BlockCondition
 *
 * @param {Array<string|RegExp|Symbol>} [routes] - Route patterns to match (passes if ANY match)
 * @param {Array<string|RegExp|Symbol>} [excludeRoutes] - Route patterns to exclude (passes if NONE match)
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

  evaluate(args) {
    const currentRoute = this.router.currentRouteName;

    if (!currentRoute) {
      return false;
    }

    const { routes, excludeRoutes } = args;

    if (excludeRoutes?.length) {
      return !this.#matchesAny(currentRoute, excludeRoutes);
    }

    if (routes?.length) {
      return this.#matchesAny(currentRoute, routes);
    }

    return true;
  }

  #matchesAny(currentRoute, patterns) {
    return patterns.some((pattern) =>
      this.#matchesPattern(currentRoute, pattern)
    );
  }

  #matchesPattern(route, pattern) {
    // Symbol shortcut pattern
    if (typeof pattern === "symbol") {
      return this.#matchesShortcut(pattern);
    }

    // RegExp pattern
    if (pattern instanceof RegExp) {
      return pattern.test(route);
    }

    // Wildcard pattern: "category.*" matches "category.none", "category.all", etc.
    if (pattern.endsWith(".*")) {
      const prefix = pattern.slice(0, -2);
      return route === prefix || route.startsWith(`${prefix}.`);
    }

    // Exact match
    return route === pattern;
  }

  #matchesShortcut(shortcut) {
    switch (shortcut) {
      case BlockRouteConditionShortcuts.CATEGORY_PAGES:
        return !!this.discovery.category;

      case BlockRouteConditionShortcuts.DISCOVERY_PAGES:
        return this.discovery.onDiscoveryRoute && !this.discovery.custom;

      case BlockRouteConditionShortcuts.HOMEPAGE:
        return this.discovery.custom;

      case BlockRouteConditionShortcuts.TAG_PAGES:
        return !!this.discovery.tag;

      case BlockRouteConditionShortcuts.TOP_MENU:
        return (
          this.discovery.onDiscoveryRoute &&
          !this.discovery.category &&
          !this.discovery.tag &&
          !this.discovery.custom
        );

      default:
        return false;
    }
  }
}
