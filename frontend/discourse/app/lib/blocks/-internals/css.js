/**
 * Manages dynamic CSS injection for block outlet containers.
 *
 * This module creates a `<style>` tag in the document head and adds CSS rules
 * for each outlet's container element. This enables container queries where
 * child blocks can query their parent outlet's size.
 *
 * @module outlet-container-css
 * @private
 */

const STYLE_TAG_ID = "block-outlet-container-css";

/**
 * Tracks which outlets have already had their CSS registered.
 * Prevents duplicate CSS rules from being added.
 *
 * @type {Set<string>}
 */
const registeredOutlets = new Set();

/**
 * Gets or creates the style tag for outlet container CSS.
 *
 * @returns {HTMLStyleElement} The style element for outlet CSS rules.
 */
function getOrCreateStyleTag() {
  let styleTag = document.getElementById(STYLE_TAG_ID);
  if (!styleTag) {
    styleTag = document.createElement("style");
    styleTag.id = STYLE_TAG_ID;
    document.head.appendChild(styleTag);
  }
  return styleTag;
}

/**
 * Registers the container query CSS for a block outlet.
 *
 * Adds a CSS rule that sets the `container` property on the outlet's container
 * element, enabling container queries in child blocks. The rule is only added
 * once per class name.
 *
 * @param {string} className - The CSS class name for the container element.
 * @param {string} containerName - The name for the CSS container query context.
 *
 * @example
 * // registerOutletContainerStyle("topic-list__container", "topic-list") adds:
 * // .topic-list__container { container: topic-list / inline-size; }
 */
export function registerOutletContainerStyle(className, containerName) {
  if (registeredOutlets.has(className)) {
    return;
  }

  registeredOutlets.add(className);

  const styleTag = getOrCreateStyleTag();
  const rule = `.${className} { container: ${containerName} / inline-size; }`;
  styleTag.textContent += rule + "\n";
}
