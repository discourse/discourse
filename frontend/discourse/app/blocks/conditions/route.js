import { service } from "@ember/service";
import {
  getParamsForPageType,
  isValidPageType,
  suggestPageType,
  VALID_PAGE_TYPES,
  validateParamsAgainstPages,
  validateParamType,
} from "discourse/lib/blocks/page-definitions";
import {
  isValidUrlPattern,
  matchesAnyPattern,
  normalizePath,
} from "discourse/lib/blocks/url-matcher";
import {
  matchParams,
  validateParamSpec,
} from "discourse/lib/blocks/value-matcher";
import { BlockCondition, raiseBlockValidationError } from "./condition";
import { blockCondition } from "./decorator";

/**
 * A condition that evaluates based on the current URL path, semantic page types,
 * route parameters, and query parameters.
 *
 * URL patterns use picomatch glob syntax:
 * - `*` matches a single path segment (no slashes)
 * - `**` matches zero or more path segments
 * - `?` matches a single character
 * - `[abc]` matches any character in the brackets
 * - `{a,b}` matches any of the comma-separated patterns
 *
 * Page types match semantic page contexts without requiring knowledge of URL structure:
 * - `CATEGORY_PAGES` - any category page (when `discovery.category` is set)
 * - `TAG_PAGES` - any tag page (when `discovery.tag` is set)
 * - `DISCOVERY_PAGES` - discovery routes (latest, top, etc.) excluding custom homepage
 * - `HOMEPAGE` - custom homepage only
 * - `TOP_MENU` - discovery routes that appear in the top navigation menu
 * - `TOPIC_PAGES` - individual topic pages
 * - `USER_PAGES` - user profile pages
 * - `ADMIN_PAGES` - admin section pages
 * - `GROUP_PAGES` - group pages
 *
 * URL matching automatically handles Discourse subfolder installations by
 * normalizing URLs before matching. Theme authors don't need to know if
 * Discourse runs on `/forum` or root - patterns like `/c/**` work everywhere.
 *
 * @class BlockRouteCondition
 * @extends BlockCondition
 *
 * @param {string[]} [urls] - URL patterns to match (passes if ANY match).
 * @param {string[]} [pages] - Page types to match (passes if ANY match).
 * @param {Object} [params] - Page parameters to match (only valid with `pages`).
 * @param {Object} [queryParams] - Query parameters to match.
 *
 * @example
 * // Match category pages using page type
 * { type: "route", pages: ["CATEGORY_PAGES"] }
 *
 * @example
 * // Match category pages using URL pattern
 * { type: "route", urls: ["/c/**"] }
 *
 * @example
 * // Match multiple page types (OR logic)
 * { type: "route", pages: ["CATEGORY_PAGES", "TAG_PAGES"] }
 *
 * @example
 * // Match specific category by ID
 * { type: "route", pages: ["CATEGORY_PAGES"], params: { id: 5 } }
 *
 * @example
 * // Match with query params
 * { type: "route", urls: ["/latest"], queryParams: { filter: "solved" } }
 *
 * @example
 * // Exclude pages using NOT combinator
 * { not: { type: "route", pages: ["ADMIN_PAGES"] } }
 */
@blockCondition({
  type: "route",
  validArgKeys: ["urls", "pages", "params", "queryParams"],
})
export default class BlockRouteCondition extends BlockCondition {
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
   * @param {string} [path] - The path to this condition in the config (for error messages).
   * @throws {Error} If validation fails.
   */
  validate(args, path) {
    const { urls, pages, params, queryParams } = args;

    // Must provide either urls or pages
    if (!urls?.length && !pages?.length) {
      raiseBlockValidationError(
        "BlockRouteCondition: Must provide `urls` or `pages`.",
        path
      );
    }

    // Validate urls
    if (urls?.length) {
      if (!Array.isArray(urls)) {
        raiseBlockValidationError(
          "BlockRouteCondition: `urls` must be an array of URL patterns.",
          path ? `${path}.urls` : undefined
        );
      }

      for (let i = 0; i < urls.length; i++) {
        const pattern = urls[i];
        const urlPath = path ? `${path}.urls[${i}]` : undefined;

        // Check for old shortcut syntax
        if (typeof pattern === "string" && pattern.startsWith("$")) {
          raiseBlockValidationError(
            `BlockRouteCondition: Shortcuts like '${pattern}' are not supported in \`urls\`.\n` +
              `Use the \`pages\` option instead:\n` +
              `  { type: "route", pages: ["${pattern.slice(1)}"] }`,
            urlPath
          );
        }

        // Validate glob pattern syntax
        if (!isValidUrlPattern(pattern)) {
          raiseBlockValidationError(
            `BlockRouteCondition: Invalid glob pattern "${pattern}". ` +
              `Check for unbalanced brackets or braces.`,
            urlPath
          );
        }
      }
    }

    // Validate pages
    if (pages?.length) {
      if (!Array.isArray(pages)) {
        raiseBlockValidationError(
          `BlockRouteCondition: \`pages\` must be an array of page type strings.\n` +
            `Example: { pages: ["CATEGORY_PAGES", "TAG_PAGES"] }`,
          path ? `${path}.pages` : undefined
        );
      }

      for (let i = 0; i < pages.length; i++) {
        const pageType = pages[i];
        const pagePath = path ? `${path}.pages[${i}]` : undefined;

        if (typeof pageType !== "string") {
          raiseBlockValidationError(
            `BlockRouteCondition: Each page type must be a string, got ${typeof pageType}.`,
            pagePath
          );
        }

        if (!isValidPageType(pageType)) {
          const suggestion = suggestPageType(pageType);
          let errorMsg = `BlockRouteCondition: Unknown page type '${pageType}'.`;
          if (suggestion) {
            errorMsg += `\nDid you mean '${suggestion}'?`;
          }
          errorMsg += `\nValid page types: ${VALID_PAGE_TYPES.join(", ")}`;
          raiseBlockValidationError(errorMsg, pagePath);
        }
      }
    }

    // Validate params
    if (params) {
      const paramsPath = path ? `${path}.params` : undefined;

      // params requires pages
      if (!pages?.length) {
        raiseBlockValidationError(
          `BlockRouteCondition: \`params\` requires \`pages\` to be specified.\n` +
            `Use \`pages\` to specify which page types to match, then \`params\` to filter by parameters.`,
          paramsPath
        );
      }

      // params cannot be used with urls
      if (urls?.length) {
        raiseBlockValidationError(
          `BlockRouteCondition: \`params\` cannot be used with \`urls\`.\n` +
            `Use \`pages\` with typed parameters instead.`,
          paramsPath
        );
      }

      // Validate params against all listed page types
      const { valid, errors } = validateParamsAgainstPages(params, pages);
      if (!valid) {
        raiseBlockValidationError(
          `BlockRouteCondition: ${errors.join("\n")}`,
          paramsPath
        );
      }

      // Validate param types
      for (const [paramName, value] of Object.entries(params)) {
        // Find a page type that has this param (we already validated it exists in all)
        const pageType = pages.find((p) => {
          const pageParams = getParamsForPageType(p);
          return pageParams && paramName in pageParams;
        });

        if (pageType) {
          const { valid: typeValid, error } = validateParamType(
            paramName,
            value,
            pageType
          );
          if (!typeValid) {
            raiseBlockValidationError(
              `BlockRouteCondition: ${error}`,
              path ? `${path}.params.${paramName}` : undefined
            );
          }
        }
      }
    }

    // Validate queryParams for operator typos (e.g., "an" vs "any")
    if (queryParams) {
      validateParamSpec(queryParams, "queryParams", (msg) => {
        raiseBlockValidationError(
          `BlockRouteCondition: ${msg}`,
          path ? `${path}.queryParams` : undefined
        );
      });
    }
  }

  /**
   * Evaluates whether the current route matches the condition.
   *
   * Evaluation logic:
   * - With `urls`: passes if ANY URL pattern matches
   * - With `pages`: passes if ANY page type matches
   * - With `params`: additionally requires all params to match (only with `pages`)
   * - With `queryParams`: additionally requires all query params to match
   *
   * @param {Object} args - The condition arguments.
   * @param {Object} [context={}] - Evaluation context (for debugging).
   * @returns {boolean} True if the condition passes.
   */
  evaluate(args, context = {}) {
    const { urls, pages, params, queryParams } = args;
    const currentPath = this.currentPath;

    // Debug context for nested logging
    const isDebugging = context.debug ?? false;
    const logger = context.logger;
    const childDepth = (context._depth ?? 0) + 1;
    const debugContext = { debug: isDebugging, _depth: childDepth, logger };

    // Get actual query params for matching
    const actualQueryParams = this.router.currentRoute?.queryParams;

    let routeMatched = false;
    let matchedPageType = null;

    // Check urls (passes if ANY match)
    if (urls?.length) {
      if (matchesAnyPattern(currentPath, urls)) {
        routeMatched = true;
      }
    }

    // Check pages (passes if ANY match)
    if (pages?.length && !routeMatched) {
      for (const pageType of pages) {
        const pageContext = this.#getPageContext(pageType);
        if (pageContext !== null) {
          // Page type matches, now check params if provided
          if (params) {
            if (this.#matchPageParams(params, pageContext, debugContext)) {
              routeMatched = true;
              matchedPageType = pageType;
              break;
            }
          } else {
            routeMatched = true;
            matchedPageType = pageType;
            break;
          }
        }
      }
    }

    // Log state when debugging
    if (isDebugging && (params || queryParams)) {
      logger?.logRouteState?.({
        currentPath,
        expectedUrls: urls,
        pages,
        params,
        matchedPageType,
        actualQueryParams,
        depth: childDepth,
        result: routeMatched,
      });
    }

    // Return early if URL/page didn't match
    if (!routeMatched) {
      return false;
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
   * Gets the current context values for a page type.
   *
   * Returns an object with the current values for all parameters defined for
   * this page type, or null if the page type doesn't match the current route.
   *
   * @param {string} pageType - The page type (e.g., "CATEGORY_PAGES").
   * @returns {Object|null} The context object, or null if page type doesn't match.
   */
  #getPageContext(pageType) {
    switch (pageType) {
      case "CATEGORY_PAGES": {
        const category = this.discovery.category;
        if (!category) {
          return null;
        }
        return {
          categoryId: category.id,
          categorySlug: category.slug,
          parentCategoryId: category.parent_category_id,
        };
      }

      case "TAG_PAGES": {
        const tag = this.discovery.tag;
        if (!tag) {
          return null;
        }
        const category = this.discovery.category;
        return {
          tagId: tag.name,
          categoryId: category?.id,
          categorySlug: category?.slug,
          parentCategoryId: category?.parent_category_id,
        };
      }

      case "DISCOVERY_PAGES": {
        if (!this.discovery.onDiscoveryRoute || this.discovery.custom) {
          return null;
        }
        const filter = this.router.currentRouteName
          ?.replace(/^discovery\./, "")
          .split(".")[0];
        return { filter };
      }

      case "HOMEPAGE":
        return this.discovery.custom ? {} : null;

      case "TOP_MENU": {
        const { discovery } = this;
        if (
          !discovery.onDiscoveryRoute ||
          discovery.category ||
          discovery.tag ||
          discovery.custom
        ) {
          return null;
        }
        const filter = this.router.currentRouteName
          ?.replace(/^discovery\./, "")
          .split(".")[0];
        return { filter };
      }

      case "TOPIC_PAGES": {
        if (!this.router.currentRouteName?.startsWith("topic.")) {
          return null;
        }
        const routeParams = this.router.currentRoute?.params || {};
        return {
          id: routeParams.id ? parseInt(routeParams.id, 10) : undefined,
          slug: routeParams.slug,
        };
      }

      case "USER_PAGES": {
        if (!this.router.currentRouteName?.startsWith("user.")) {
          return null;
        }
        const routeParams = this.router.currentRoute?.params || {};
        return { username: routeParams.username };
      }

      case "ADMIN_PAGES":
        return this.router.currentRouteName?.startsWith("admin") ? {} : null;

      case "GROUP_PAGES": {
        if (!this.router.currentRouteName?.startsWith("group.")) {
          return null;
        }
        const routeParams = this.router.currentRoute?.params || {};
        return { name: routeParams.name };
      }

      default:
        return null;
    }
  }

  /**
   * Matches page parameters against the current context.
   *
   * @param {Object} params - The expected params from the condition.
   * @param {Object} pageContext - The actual context values from the current page.
   * @param {Object} debugContext - Debug context for logging.
   * @returns {boolean} True if all params match.
   */
  #matchPageParams(params, pageContext, debugContext) {
    for (const [paramName, expectedValue] of Object.entries(params)) {
      const actualValue = pageContext[paramName];

      // Simple equality check for now
      // Could be extended to support arrays, NOT, etc. like matchParams
      if (actualValue !== expectedValue) {
        if (debugContext.debug) {
          debugContext.logger?.logParamMismatch?.({
            paramName,
            expected: expectedValue,
            actual: actualValue,
            depth: debugContext._depth,
          });
        }
        return false;
      }
    }
    return true;
  }
}
