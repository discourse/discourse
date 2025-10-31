import Helper from "@ember/component/helper";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";

/**
 * Ember Helper for registering accessibility skip links.
 *
 * Usage:
 *   {{a11ySkipLink
 *     href="/target"
 *     label="Skip to content"
 *     onClick=this.handleClick
 *     classNames="skip-link"
 *     id="main-skip-link"
 *     position="top"
 *   }}
 *
 * @class A11ySkipLink
 * @extends Helper
 *
 * @param {Array} _ - Positional arguments (unused)
 * @param {Object} namedArgs - Named arguments
 * @param {string} namedArgs.href - The target selector or URL for the skip link
 * @param {Function} [namedArgs.onClick] - Optional click handler for the skip link
 * @param {string} namedArgs.label - The text label for the skip link
 * @param {string} [namedArgs.classNames] - Optional CSS classes to apply to the skip link
 * @param {string} [namedArgs.id] - Optional ID for the skip link element
 * @param {string} [namedArgs.position] - Optional position for the skip link (e.g., 'top', 'bottom')
 * @returns {void}
 */
export default class A11ySkipLink extends Helper {
  @service a11ySkipLinks;

  /**
   * Registers a skip link with the a11ySkipLinks service and sets up automatic cleanup.
   *
   * @param {Array} _ - Positional arguments (unused)
   * @param {Object} namedArgs - Named arguments
   * @param {string} namedArgs.href - The target selector or URL for the skip link
   * @param {Function} [namedArgs.onClick] - Optional click handler for the skip link
   * @param {string} namedArgs.label - The text label for the skip link
   * @param {string} [namedArgs.classNames] - Optional CSS classes to apply to the skip link
   * @param {string} [namedArgs.id] - Optional ID for the skip link element
   * @param {string} [namedArgs.position] - Optional position for the skip link (e.g., 'top', 'bottom')
   */
  compute(_, { href, onClick, label, classNames, id, position }) {
    const skipLinkDef = { href, onClick, label, classNames, id, position };
    schedule("afterRender", this, () =>
      // registering the helper will update a tracked context. we need to perform it outside the render cycle to
      // prevent errors.
      this.a11ySkipLinks.registerHelper(this, skipLinkDef)
    );
  }
}
