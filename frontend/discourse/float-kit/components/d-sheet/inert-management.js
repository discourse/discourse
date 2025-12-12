/**
 * @class InertManagement
 * Manages aria-modal on the sheet view.
 * Aria-hidden management is now centralized in sheetRegistry.
 */
export default class InertManagement {
  /** @type {Object} */
  controller;

  /**
   * @param {Object} controller - The sheet controller instance
   */
  constructor(controller) {
    this.controller = controller;
  }

  /**
   * Apply aria-modal to the view.
   */
  applyInertOutside() {
    if (!this.controller.inertOutside || !this.controller.view) {
      return;
    }

    this.controller.view.setAttribute("aria-modal", "true");
  }

  /**
   * Remove aria-modal from the view.
   */
  removeInertOutside() {
    this.controller.view?.removeAttribute("aria-modal");
  }

  /**
   * Cleanup - just removes aria-modal.
   */
  cleanup() {
    this.removeInertOutside();
  }
}
