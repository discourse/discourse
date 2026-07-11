import cssIdentifier from "discourse/helpers/css-identifier";

/**
 * Returns the CSS-safe version of an outlet name.
 *
 * Converts namespaced outlet names (e.g., "plugin:outlet") to valid CSS
 * identifiers by replacing colons with hyphens and dasherizing.
 *
 * @param outletName - The outlet name (e.g., "hero-blocks", "plugin:sidebar").
 * @returns The CSS-safe name (e.g., "hero-blocks", "plugin-sidebar").
 */
export function outletClassName(outletName: string): string {
  return cssIdentifier(outletName);
}

/**
 * Returns the container CSS class name for a block outlet, following the
 * BEM-like pattern `{safe-outlet-name}__container` (e.g. "hero-blocks" →
 * "hero-blocks__container").
 *
 * @param outletName - The outlet name (e.g., "hero-blocks", "plugin:sidebar").
 * @returns The CSS class name (e.g., "hero-blocks__container").
 */
export function outletContainerClassName(outletName: string): string {
  return `${outletClassName(outletName)}__container`;
}

/**
 * Returns the layout CSS class name for a block outlet, following the BEM-like
 * pattern `{safe-outlet-name}__layout` (e.g. "hero-blocks" →
 * "hero-blocks__layout").
 *
 * @param outletName - The outlet name (e.g., "hero-blocks", "plugin:sidebar").
 * @returns The CSS class name (e.g., "hero-blocks__layout").
 */
export function outletLayoutClassName(outletName: string): string {
  return `${outletClassName(outletName)}__layout`;
}

/**
 * Returns the CSS container-query rule for a block outlet, enabling
 * `@container` queries inside the outlet by setting the `container` property on
 * its container element.
 *
 * @param outletName - The outlet name (e.g., "hero-blocks").
 * @returns The CSS rule (e.g., `.hero-blocks__container { container: hero-blocks / inline-size; }`).
 */
export function outletContainerRule(outletName: string): string {
  return `.${outletContainerClassName(outletName)} { container: ${outletName} / inline-size; }`;
}
