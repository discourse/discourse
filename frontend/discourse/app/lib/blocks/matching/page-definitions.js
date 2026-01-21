// @ts-check
import { findClosestMatch } from "discourse/lib/string-similarity";

/**
 * Page type definitions for the route condition.
 *
 * This is a pure data structure that defines the available page types
 * and their parameters. The evaluation logic is in route.js.
 *
 * @typedef {Object} ParamDefinition
 * @property {"string"|"number"} type - The expected type of the parameter.
 * @property {string} description - A description of the parameter.
 *
 * @typedef {Object} PageDefinition
 * @property {string} description - A description of the page type.
 * @property {Object<string, ParamDefinition>} params - The parameters for this page type.
 */

/**
 * Definitions for all supported page types.
 *
 * Each page type has:
 * - `description`: A human-readable description of what pages this matches.
 * - `params`: An object mapping parameter names to their definitions.
 *
 * @type {Object<string, PageDefinition>}
 */
export const PAGE_DEFINITIONS = {
  /**
   * Category listing pages (/c/slug, /c/parent/child).
   * Matches when discovery.category is set.
   */
  CATEGORY_PAGES: {
    description: "Category listing pages",
    params: {
      categoryId: {
        type: "number",
        description: "Category ID",
      },
      categorySlug: {
        type: "string",
        description: "Category slug (URL-safe name)",
      },
      parentCategoryId: {
        type: "number",
        description: "Parent category ID (for subcategories)",
      },
    },
  },

  /**
   * Tag listing pages (/tag/name, /tags/intersection/tag1/tag2).
   * Matches when discovery.tag is set.
   */
  TAG_PAGES: {
    description: "Tag listing pages",
    params: {
      tagId: {
        type: "string",
        description: "Tag name/ID",
      },
      categoryId: {
        type: "number",
        description: "Category ID (when tag is filtered by category)",
      },
      categorySlug: {
        type: "string",
        description: "Category slug (when tag is filtered by category)",
      },
      parentCategoryId: {
        type: "number",
        description: "Parent category ID (when tag is filtered by subcategory)",
      },
    },
  },

  /**
   * Discovery routes (latest, top, new, unread, hot, etc.).
   * Excludes custom homepage.
   */
  DISCOVERY_PAGES: {
    description:
      "Discovery routes (latest, top, new, etc.) excluding custom homepage",
    params: {
      filter: {
        type: "string",
        description: "The discovery filter type (e.g., 'latest', 'top', 'new')",
      },
    },
  },

  /**
   * Custom homepage only (discovery.custom route).
   */
  HOMEPAGE: {
    description: "Custom homepage only",
    params: {},
  },

  /**
   * Top navigation discovery routes.
   * Excludes category pages, tag pages, and custom homepage.
   */
  TOP_MENU: {
    description:
      "Top navigation discovery routes (excludes category, tag, homepage)",
    params: {
      filter: {
        type: "string",
        description: "The filter type (e.g., 'latest', 'top', 'new')",
      },
    },
  },

  /**
   * Individual topic pages (/t/slug/id).
   */
  TOPIC_PAGES: {
    description: "Individual topic pages",
    params: {
      id: {
        type: "number",
        description: "Topic ID",
      },
      slug: {
        type: "string",
        description: "Topic slug",
      },
    },
  },

  /**
   * User profile pages (/u/username).
   */
  USER_PAGES: {
    description: "User profile pages",
    params: {
      username: {
        type: "string",
        description: "Username being viewed",
      },
    },
  },

  /**
   * Admin section pages (/admin/**).
   */
  ADMIN_PAGES: {
    description: "Admin section pages",
    params: {},
  },

  /**
   * Group pages (/g/groupname).
   */
  GROUP_PAGES: {
    description: "Group pages",
    params: {
      name: {
        type: "string",
        description: "Group name",
      },
    },
  },
};

/**
 * Array of all valid page type names.
 *
 * @type {string[]}
 */
export const VALID_PAGE_TYPES = Object.keys(PAGE_DEFINITIONS);

/**
 * Checks if a page type is valid.
 *
 * @param {string} pageType - The page type to check.
 * @returns {boolean} True if the page type is valid.
 */
export function isValidPageType(pageType) {
  return pageType in PAGE_DEFINITIONS;
}

/**
 * Gets the parameter definitions for a page type.
 *
 * @param {string} pageType - The page type.
 * @returns {Object<string, ParamDefinition>|null} The parameter definitions, or null if invalid.
 */
export function getParamsForPageType(pageType) {
  const definition = PAGE_DEFINITIONS[pageType];
  return definition ? definition.params : null;
}

/**
 * Gets all valid parameter names for a page type.
 *
 * @param {string} pageType - The page type.
 * @returns {string[]} Array of valid parameter names.
 */
export function getValidParamNames(pageType) {
  const params = getParamsForPageType(pageType);
  return params ? Object.keys(params) : [];
}

/**
 * Suggests a page type for a potential typo using fuzzy matching.
 *
 * @param {string} typo - The potentially misspelled page type.
 * @returns {string|null} The suggested page type, or null if no good match found.
 */
export function suggestPageType(typo) {
  return findClosestMatch(typo, VALID_PAGE_TYPES);
}

/**
 * Validates that all provided params are valid for ALL listed page types.
 *
 * @param {Object} params - The params object to validate.
 * @param {string[]} pages - The array of page types.
 * @returns {{valid: boolean, errors: string[]}} Validation result with any errors.
 */
export function validateParamsAgainstPages(params, pages) {
  const errors = [];

  if (!params || typeof params !== "object") {
    return { valid: true, errors: [] };
  }

  const paramNames = Object.keys(params);
  if (paramNames.length === 0) {
    return { valid: true, errors: [] };
  }

  for (const paramName of paramNames) {
    const validFor = [];
    const invalidFor = [];

    for (const pageType of pages) {
      const pageParams = getParamsForPageType(pageType);
      if (pageParams && paramName in pageParams) {
        validFor.push(pageType);
      } else {
        invalidFor.push(pageType);
      }
    }

    if (invalidFor.length > 0) {
      if (validFor.length > 0) {
        // Param is valid for some but not all page types
        errors.push(
          `Parameter '${paramName}' is not valid for all listed page types.\n` +
            `'${paramName}' is valid for: ${validFor.join(", ")}\n` +
            `'${paramName}' is NOT valid for: ${invalidFor.join(", ")}\n` +
            `All params must be valid for ALL page types when multiple pages are listed.`
        );
      } else {
        // Param is not valid for any page type
        const validParams = pages
          .flatMap((p) => getValidParamNames(p))
          .filter((v, i, a) => a.indexOf(v) === i); // unique
        errors.push(
          `Parameter '${paramName}' is not valid for any of the listed page types.\n` +
            `Valid parameters across listed pages: ${validParams.join(", ") || "(none)"}`
        );
      }
    }
  }

  return { valid: errors.length === 0, errors };
}

/**
 * Validates the type of a parameter value against its definition.
 *
 * @param {string} paramName - The parameter name.
 * @param {*} value - The value to validate.
 * @param {string} pageType - The page type (for error messages).
 * @returns {{valid: boolean, error: string|null}} Validation result.
 */
export function validateParamType(paramName, value, pageType) {
  const params = getParamsForPageType(pageType);
  if (!params || !(paramName in params)) {
    return { valid: false, error: `Unknown parameter '${paramName}'` };
  }

  const definition = params[paramName];
  const actualType = typeof value;

  if (definition.type === "number") {
    if (actualType !== "number") {
      return {
        valid: false,
        error:
          `Parameter '${paramName}' must be a number, got ${actualType} '${value}'.\n` +
          `Hint: Use numeric value: { params: { ${paramName}: ${parseInt(value, 10) || 123} } }`,
      };
    }
  } else if (definition.type === "string") {
    if (actualType !== "string") {
      return {
        valid: false,
        error: `Parameter '${paramName}' must be a string, got ${actualType} '${value}'.`,
      };
    }
  }

  return { valid: true, error: null };
}

/**
 * Gets the current context values for a page type.
 *
 * Returns an object with the current values for all parameters defined for
 * this page type, or null if the page type doesn't match the current route.
 *
 * @param {string} pageType - The page type (e.g., "CATEGORY_PAGES").
 * @param {Object} services - Injected services for context extraction.
 * @param {Object} services.router - The Ember router service.
 * @param {Object} services.discovery - The Discourse discovery service.
 * @returns {Object|null} The context object with param values, or null if page type doesn't match.
 *
 * @example
 * const context = getPageContext("CATEGORY_PAGES", { router, discovery });
 * // Returns { categoryId: 5, categorySlug: "general", parentCategoryId: null }
 * // or null if not on a category page
 */
export function getPageContext(pageType, { router, discovery }) {
  switch (pageType) {
    case "CATEGORY_PAGES": {
      const category = discovery.category;
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
      const tag = discovery.tag;
      if (!tag) {
        return null;
      }
      const category = discovery.category;
      return {
        tagId: tag.name,
        categoryId: category?.id,
        categorySlug: category?.slug,
        parentCategoryId: category?.parent_category_id,
      };
    }

    case "DISCOVERY_PAGES": {
      if (!discovery.onDiscoveryRoute || discovery.custom) {
        return null;
      }
      const filter = router.currentRouteName
        ?.replace(/^discovery\./, "")
        .split(".")[0];
      return { filter };
    }

    case "HOMEPAGE":
      return discovery.custom ? {} : null;

    case "TOP_MENU": {
      if (
        !discovery.onDiscoveryRoute ||
        discovery.category ||
        discovery.tag ||
        discovery.custom
      ) {
        return null;
      }
      const filter = router.currentRouteName
        ?.replace(/^discovery\./, "")
        .split(".")[0];
      return { filter };
    }

    case "TOPIC_PAGES": {
      if (!router.currentRouteName?.startsWith("topic.")) {
        return null;
      }
      const routeParams = router.currentRoute?.params || {};
      return {
        id: routeParams.id ? parseInt(routeParams.id, 10) : undefined,
        slug: routeParams.slug,
      };
    }

    case "USER_PAGES": {
      if (!router.currentRouteName?.startsWith("user.")) {
        return null;
      }
      const routeParams = router.currentRoute?.params || {};
      return { username: routeParams.username };
    }

    case "ADMIN_PAGES":
      return router.currentRouteName?.startsWith("admin") ? {} : null;

    case "GROUP_PAGES": {
      if (!router.currentRouteName?.startsWith("group.")) {
        return null;
      }
      const routeParams = router.currentRoute?.params || {};
      return { name: routeParams.name };
    }

    default:
      return null;
  }
}

/**
 * Determines the current page type by checking all known page types.
 *
 * Iterates through all valid page types and returns the first one that matches
 * the current route. Useful for debugging to show what page the user is on.
 *
 * @param {Object} services - Injected services for context extraction.
 * @param {Object} services.router - The Ember router service.
 * @param {Object} services.discovery - The Discourse discovery service.
 * @returns {string|null} The current page type, or null if no match.
 *
 * @example
 * const pageType = getCurrentPageType({ router, discovery });
 * // Returns "CATEGORY_PAGES", "TOPIC_PAGES", etc., or null
 */
export function getCurrentPageType({ router, discovery }) {
  for (const pageType of VALID_PAGE_TYPES) {
    if (getPageContext(pageType, { router, discovery }) !== null) {
      return pageType;
    }
  }
  return null;
}
