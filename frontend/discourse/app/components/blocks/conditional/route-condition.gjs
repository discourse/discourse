import Component from "@glimmer/component";
import { DEBUG } from "@glimmer/env";
import { service } from "@ember/service";
import { block } from "discourse/components/block-outlet";

/**
 * Route shortcut symbols for common route conditions.
 * Use these with RouteCondition's `routes` or `excludeRoutes` args.
 *
 * @property {Symbol} DISCOVERY - Any discovery route (latest, top, etc.) excluding custom homepage
 * @property {Symbol} HOMEPAGE - Custom homepage route only
 * @property {Symbol} CATEGORY - Any category route
 * @property {Symbol} TOP_MENU - Discovery routes excluding category, tag, and custom homepage
 */
export const RouteShortcuts = Object.freeze({
  DISCOVERY: Symbol("route:discovery"),
  HOMEPAGE: Symbol("route:homepage"),
  CATEGORY: Symbol("route:category"),
  TOP_MENU: Symbol("route:top-menu"),
});

/**
 * A conditional container block that renders children only when the current
 * route matches specified patterns.
 *
 * @component RouteCondition
 * @param {Array<string|RegExp|Symbol>} [routes] - Route patterns to match (renders if ANY match)
 * @param {Array<string|RegExp|Symbol>} [excludeRoutes] - Route patterns to exclude (renders if NONE match)
 *
 * **IMPORTANT:** You must use either `routes` OR `excludeRoutes`, not both.
 * Providing both arguments will throw an error in development/testing mode and log
 * a warning in production.
 *
 * Route patterns support:
 * - Exact match: "discovery.latest"
 * - Wildcard suffix: "category.*" matches "category.none", "category.all", etc.
 * - Regular expression: /^topic\.\d+$/ for advanced matching
 * - Route shortcuts: RouteShortcuts.DISCOVERY, RouteShortcuts.HOMEPAGE, etc.
 *
 * When using `routes`, children render if the current route matches ANY pattern (OR logic).
 * When using `excludeRoutes`, children render if the current route matches NONE of the patterns.
 *
 * @example
 * // Render only on category routes (using wildcard)
 * {
 *   block: RouteCondition,
 *   args: { routes: ["category", "category.*"] },
 *   children: [
 *     { block: BlockCategoryBanner }
 *   ]
 * }
 *
 * @example
 * // Render everywhere except homepage
 * {
 *   block: RouteCondition,
 *   args: { excludeRoutes: ["discovery.custom"] },
 *   children: [
 *     { block: BlockSidebar }
 *   ]
 * }
 *
 * @example
 * // Render on discovery routes using regex
 * {
 *   block: RouteCondition,
 *   args: { routes: [/^discovery\./] },
 *   children: [
 *     { block: BlockDiscoveryHeader }
 *   ]
 * }
 *
 * @example
 * // Render on discovery routes using shortcut
 * import { RouteShortcuts } from "discourse/components/blocks/conditional/route-condition";
 * {
 *   block: RouteCondition,
 *   args: { routes: [RouteShortcuts.DISCOVERY] },
 *   children: [
 *     { block: BlockDiscoveryHeader }
 *   ]
 * }
 */
@block("route-condition", { container: true })
export default class RouteCondition extends Component {
  @service discovery;
  @service router;

  constructor() {
    super(...arguments);
    this.#validateArgs();
  }

  get shouldRender() {
    const currentRoute = this.router.currentRouteName;

    if (!currentRoute) {
      return false;
    }

    const { routes, excludeRoutes } = this.args;

    if (excludeRoutes?.length) {
      return !this.#matchesAny(currentRoute, excludeRoutes);
    }

    if (routes?.length) {
      return this.#matchesAny(currentRoute, routes);
    }

    // No conditions specified, always render
    return true;
  }

  #validateArgs() {
    const { routes, excludeRoutes } = this.args;

    if (routes?.length && excludeRoutes?.length) {
      const message =
        "RouteCondition: Cannot use both `routes` and `excludeRoutes` arguments. Use one or the other.";

      if (DEBUG) {
        throw new Error(message);
      } else {
        // eslint-disable-next-line no-console
        console.warn(message);
      }
    }
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
      case RouteShortcuts.DISCOVERY:
        return this.discovery.onDiscoveryRoute && !this.discovery.custom;

      case RouteShortcuts.HOMEPAGE:
        return this.discovery.custom;

      case RouteShortcuts.CATEGORY:
        return !!this.discovery.category;

      case RouteShortcuts.TOP_MENU:
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

  <template>
    {{#if this.shouldRender}}
      {{#each this.children as |child|}}
        <child.Component @outletName={{@outletName}} />
      {{/each}}
    {{/if}}
  </template>
}
