/**
 * Base class representing a sidebar section button interface.
 */
export default class BaseCustomSidebarSectionButton {
  constructor({ sidebar, router } = {}) {
    this.sidebar = sidebar;
    this.router = router;
  }

  /**
   * @returns {string} The label of the section button
   */
  get label() {
    this._notImplemented();
  }

  /**
   * @returns {string} The icon of the section button
   */
  get icon() {
    this._notImplemented();
  }

  /**
   * @returns {Function} Action for button
   */
  get action() {
    this._notImplemented();
  }

  _notImplemented() {
    throw "not implemented";
  }
}
