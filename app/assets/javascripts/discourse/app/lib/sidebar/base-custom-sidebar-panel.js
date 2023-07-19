/**
 * Base class representing a sidebar section header interface.
 */
export default class BaseCustomSidebarPanel {
  sections = [];

  /**
   * @returns {string} Identifier for sidebar panel
   */
  get key() {
    this.#notImplemented();
  }

  /**
   * @returns {string} Text for the switch button
   */
  get switchButtonLabel() {
    this.#notImplemented();
  }

  /**
   * @returns {string} Icon for the switch button
   */
  get switchButtonIcon() {
    this.#notImplemented();
  }

  /**
   * @returns {string} Default path to panel
   */
  get switchButtonDefaultUrl() {
    this.#notImplemented();
  }

  #notImplemented() {
    throw "not implemented";
  }
}
