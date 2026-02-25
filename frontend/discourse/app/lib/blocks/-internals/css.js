// @ts-check
import cssIdentifier from "discourse/helpers/css-identifier";

/**
 * Returns the CSS-safe version of an outlet name.
 *
 * Converts namespaced outlet names (e.g., "plugin:outlet") to valid CSS
 * identifiers by replacing colons with hyphens and dasherizing.
 *
 * @param {string} outletName - The outlet name (e.g., "hero-blocks", "plugin:sidebar").
 * @returns {string} The CSS-safe name (e.g., "hero-blocks", "plugin-sidebar").
 */
export function outletClassName(outletName) {
  return cssIdentifier(outletName);
}

/**
 * Returns the container CSS class name for a block outlet.
 *
 * Follows the BEM-like pattern: `{safe-outlet-name}__container`.
 * For example, outlet "hero-blocks" produces "hero-blocks__container".
 *
 * @param {string} outletName - The outlet name (e.g., "hero-blocks", "plugin:sidebar").
 * @returns {string} The CSS class name (e.g., "hero-blocks__container").
 */
export function outletContainerClassName(outletName) {
  return `${outletClassName(outletName)}__container`;
}

/**
 * Returns the layout CSS class name for a block outlet.
 *
 * Follows the BEM-like pattern: `{safe-outlet-name}__layout`.
 * For example, outlet "hero-blocks" produces "hero-blocks__layout".
 *
 * @param {string} outletName - The outlet name (e.g., "hero-blocks", "plugin:sidebar").
 * @returns {string} The CSS class name (e.g., "hero-blocks__layout").
 */
export function outletLayoutClassName(outletName) {
  return `${outletClassName(outletName)}__layout`;
}

/**
 * Returns the CSS container query rule for a block outlet.
 *
 * Generates the CSS that enables `@container` queries inside block outlets
 * by setting the `container` property on the outlet's container element.
 *
 * @param {string} outletName - The outlet name (e.g., "hero-blocks").
 * @returns {string} The CSS rule (e.g., `.hero-blocks__container { container: hero-blocks / inline-size; }`).
 */
export function outletContainerRule(outletName) {
  return `.${outletContainerClassName(outletName)} { container: ${outletName} / inline-size; }`;
}
