// @ts-check
import { service } from "@ember/service";
import {
  getCurrentPageType,
  getPageContext,
  getParamsForPageType,
  isValidPageType,
  VALID_PAGE_TYPES,
  validateParamsAgainstPages,
  validateParamType,
} from "discourse/lib/blocks/matching/page-definitions";
import {
  matchesAnyPattern,
  normalizePath,
} from "discourse/lib/blocks/matching/url-matcher";
import {
  matchParams,
  validateParamSpec,
} from "discourse/lib/blocks/matching/value-matcher";
import { isValidGlobPattern } from "discourse/lib/glob-utils";
import { BlockCondition } from "./condition";
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
 * { type: "route", pages: ["CATEGORY_PAGES"], params: { categoryId: 5 } }
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
  args: {
    urls: { type: "array", itemType: "string" },
    pages: { type: "array", itemType: "string", itemEnum: VALID_PAGE_TYPES },
    params: { type: "any" },
    queryParams: { type: "any" },
  },
  constraints: {
    atLeastOne: ["urls", "pages"],
    requires: { params: "pages" },
    atMostOne: ["params", "urls"],
  },
  validate(args) {
    const { urls, pages, params, queryParams } = args;

    // Validate urls
    if (urls?.length) {
      for (let i = 0; i < urls.length; i++) {
        const pattern = urls[i];

        // Check for page type names mistakenly used in urls
        if (isValidPageType(pattern)) {
          return (
            `Page shortcuts like '${pattern}' are not supported in \`urls\`.\n` +
            `Use the \`pages\` option instead:\n` +
            `  { type: "route", pages: ["${pattern}"] }`
          );
        }

        // Validate glob pattern syntax
        if (!isValidGlobPattern(pattern)) {
          return (
            `Invalid glob pattern "${pattern}". ` +
            `Check for unbalanced brackets or braces.`
          );
        }
      }
    }

    // Validate params
    if (params) {
      // Handle any/not operators in params
      const paramsError = validateParamsWithOperators(params, pages, "params");
      if (paramsError) {
        return paramsError;
      }
    }

    // Validate queryParams for operator typos (e.g., "an" vs "any")
    if (queryParams) {
      let queryParamsError = null;
      validateParamSpec(queryParams, "queryParams", (msg) => {
        queryParamsError = msg;
      });
      if (queryParamsError) {
        return queryParamsError;
      }
    }

    return null;
  },
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
    let actualPageContext = null;

    // Check urls (passes if ANY match)
    if (urls?.length) {
      if (matchesAnyPattern(currentPath, urls)) {
        routeMatched = true;
      }
    }

    // Check pages (passes if ANY match)
    const services = { router: this.router, discovery: this.discovery };
    if (pages?.length && !routeMatched) {
      for (const pageType of pages) {
        const pageContext = getPageContext(pageType, services);
        if (pageContext !== null) {
          // Track page context for debugging (shows what values were checked)
          if (isDebugging) {
            actualPageContext = { pageType, ...pageContext };
          }

          // Page type matches, now check params if provided
          if (params) {
            // Pass debug=false here - logging happens in dedicated block below
            if (this.#matchPageParams(params, pageContext, { debug: false })) {
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

    // Log route state for conditions using pages or queryParams with urls
    if (isDebugging && (pages?.length || (urls?.length && queryParams))) {
      logger?.logRouteState?.({
        currentPath,
        expectedUrls: urls,
        pages,
        matchedPageType,
        actualPageType: actualPageContext ? null : getCurrentPageType(services),
        actualPageContext,
        depth: childDepth,
        result: routeMatched,
      });
    }

    // Log params with nesting (like queryParams)
    if (isDebugging && params && actualPageContext) {
      // Log params summary before nested checks (result updated after)
      const paramsSpec = { _isParams: true };
      logger?.logCondition?.({
        type: "params",
        args: {
          actual: this.#extractParamValues(params, actualPageContext),
          expected: params,
        },
        result: null,
        depth: childDepth,
        conditionSpec: paramsSpec,
      });

      // Call #matchPageParams with debug=true to log nested OR/NOT/param checks
      const paramsContext = { debug: true, _depth: childDepth + 1, logger };
      const paramsMatched = this.#matchPageParams(
        params,
        actualPageContext,
        paramsContext
      );

      // Update params summary result
      logger?.updateConditionResult?.(paramsSpec, paramsMatched);
    }

    // Return early if URL/page didn't match (unless debugging, where we show queryParams)
    if (!routeMatched && !isDebugging) {
      return false;
    }

    // Check query params (uses shared matcher with AND/OR/NOT support)
    if (queryParams) {
      // Log queryParams summary before matchParams (result updated after)
      // Use an object as conditionSpec so we can update the result
      const queryParamsSpec = isDebugging ? { _isQueryParams: true } : null;
      if (isDebugging) {
        logger?.logCondition?.({
          type: "queryParams",
          args: { actual: actualQueryParams, expected: queryParams },
          result: null, // Will be updated after matchParams
          depth: childDepth,
          conditionSpec: queryParamsSpec,
        });
      }

      // Pass deeper context so OR/AND/NOT logs nest under the queryParams summary
      const queryParamsContext = {
        ...debugContext,
        _depth: childDepth + 1,
      };

      const queryParamsMatched = matchParams({
        actualParams: actualQueryParams,
        expectedParams: queryParams,
        context: queryParamsContext,
        label: "queryParams",
      });

      // Update the queryParams summary result
      if (isDebugging) {
        logger?.updateConditionResult?.(queryParamsSpec, queryParamsMatched);
      }

      // Both URL/page AND queryParams must match
      if (!routeMatched || !queryParamsMatched) {
        return false;
      }
    }

    return routeMatched;
  }

  /**
   * Matches page parameters against the current context.
   * Supports any/not operators for complex matching.
   *
   * @param {Object} params - The expected params from the condition.
   * @param {Object} pageContext - The actual context values from the current page.
   * @param {Object} debugContext - Debug context for logging.
   * @returns {boolean} True if params match.
   */
  #matchPageParams(params, pageContext, debugContext) {
    // Recursive matching with operators:
    // - { any: [...] } - OR logic, passes if any spec matches
    // - { not: {...} } - Negation, passes if inner spec does NOT match
    // - { key: value } - Simple match, all keys must match (AND logic)
    const isLoggingEnabled = debugContext.debug ?? false;
    const depth = debugContext._depth ?? 0;
    const logger = debugContext.logger;

    // Handle any operator: { any: [{ categoryId: 1 }, { categoryId: 2 }] }
    if (params.any !== undefined) {
      const specs = params.any;

      // Log combinator BEFORE children so it appears first in tree
      if (isLoggingEnabled) {
        logger?.logCondition?.({
          type: "OR",
          args: `${specs.length} params specs`,
          result: null,
          depth,
          conditionSpec: params,
        });
      }

      const results = specs.map((spec) =>
        this.#matchPageParams(spec, pageContext, {
          debug: isLoggingEnabled,
          _depth: depth + 1,
          logger,
        })
      );
      const anyPassed = results.some(Boolean);

      // Update combinator result after children evaluated
      if (isLoggingEnabled) {
        logger?.updateCombinatorResult?.(params, anyPassed);
      }
      return anyPassed;
    }

    // Handle not operator: { not: { categoryId: 3 } }
    if (params.not !== undefined) {
      // Log combinator BEFORE children so it appears first in tree
      if (isLoggingEnabled) {
        logger?.logCondition?.({
          type: "NOT",
          args: null,
          result: null,
          depth,
          conditionSpec: params,
        });
      }

      const innerResult = this.#matchPageParams(params.not, pageContext, {
        debug: isLoggingEnabled,
        _depth: depth + 1,
        logger,
      });
      const result = !innerResult;

      // Update combinator result after children evaluated
      if (isLoggingEnabled) {
        logger?.updateCombinatorResult?.(params, result);
      }
      return result;
    }

    // Simple params object - all must match
    // Log individual param checks
    const matches = [];
    for (const [paramName, expectedValue] of Object.entries(params)) {
      const actualValue = pageContext[paramName];
      const result = actualValue === expectedValue;
      matches.push({
        key: paramName,
        expected: expectedValue,
        actual: actualValue,
        result,
      });
    }

    const allPassed = matches.every((m) => m.result);

    // Log as a nested group with all param matches
    if (isLoggingEnabled) {
      logger?.logParamGroup?.({
        label: "params",
        matches,
        result: allPassed,
        depth,
      });
    }

    return allPassed;
  }

  /**
   * Extracts param values from page context for the specified params.
   * Handles any/not operators by extracting from nested param objects.
   *
   * @param {Object} params - The expected params (keys to extract).
   * @param {Object} pageContext - The page context containing actual values.
   * @returns {Object} Object with only the requested param keys and their actual values.
   */
  #extractParamValues(params, pageContext) {
    // Handle any/not operators - extract from first nested object for display
    if (params.any !== undefined && params.any.length > 0) {
      return this.#extractParamValues(params.any[0], pageContext);
    }
    if (params.not !== undefined) {
      return this.#extractParamValues(params.not, pageContext);
    }

    const result = {};
    for (const key of Object.keys(params)) {
      result[key] = pageContext[key];
    }
    return result;
  }
}

/**
 * Validates params with support for any/not operators.
 * This is a standalone function to keep decorator config clean.
 *
 * @param {Object} params - The params to validate.
 * @param {Array<string>} pages - The page types to validate against.
 * @param {string} [path="params"] - Path for error messages.
 * @returns {string|null} Error or null if valid.
 */
function validateParamsWithOperators(params, pages, path = "params") {
  // Handle any operator: { any: [{ categoryId: 1 }, { categoryId: 2 }] }
  if (params.any !== undefined) {
    if (!Array.isArray(params.any)) {
      return `\`any\` in params must be an array of param objects.`;
    }
    for (let i = 0; i < params.any.length; i++) {
      const nestedError = validateParamsWithOperators(
        params.any[i],
        pages,
        `${path}.any[${i}]`
      );
      if (nestedError) {
        return nestedError;
      }
    }
    return null;
  }

  // Handle not operator: { not: { categoryId: 3 } }
  if (params.not !== undefined) {
    return validateParamsWithOperators(params.not, pages, `${path}.not`);
  }

  // Simple params object - validate against page types
  const { valid, errors } = validateParamsAgainstPages(params, pages);
  if (!valid) {
    return errors.join("\n");
  }

  // Validate param types
  for (const [paramName, value] of Object.entries(params)) {
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
        return error;
      }
    }
  }

  return null;
}
