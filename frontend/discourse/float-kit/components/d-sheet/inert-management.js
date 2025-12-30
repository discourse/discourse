/**
 * Manages accessibility attributes on the sheet view to ensure content
 * outside the active sheet is handled correctly by assistive technologies.
 */
export default class InertManagement {
  /**
   * @type {Object}
   */
  #controller;

  /**
   * @param {Object} controller The sheet controller instance
   */
  constructor(controller) {
    this.#controller = controller;
  }

  /**
   * Applies the modal attribute to the view to indicate its modal nature.
   */
  applyInertOutside() {
    if (!this.#controller.inertOutside || !this.#controller.view) {
      return;
    }

    this.#controller.view.setAttribute("aria-modal", "true");
  }

  /**
   * Removes the modal attribute from the view.
   */
  removeInertOutside() {
    this.#removeAriaModal();
  }

  /**
   * Final cleanup of accessibility attributes.
   */
  cleanup() {
    this.#removeAriaModal();
  }

  /**
   * Internal helper to safely remove the modal attribute from the view.
   */
  #removeAriaModal() {
    this.#controller.view?.removeAttribute("aria-modal");
  }
}
