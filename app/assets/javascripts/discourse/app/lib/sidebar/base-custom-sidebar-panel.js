import { tracked } from "@glimmer/tracking";

/**
 * Base class representing a sidebar section header interface.
 */
export default class BaseCustomSidebarPanel {
  @tracked sections = [];

  /**
   * @returns {boolean} Controls whether the panel is hidden, which means that
   * it will not show up in combined sidebar mode, and its switch button will
   * never show either.
   */
  get hidden() {
    return false;
  }

  /**
   * @returns {string} Identifier for sidebar panel
   */
  get key() {
    this.#notImplemented();
  }

  /**
   * @returns {string} Text for the switch button. Obsolete when panel is hidden.
   */
  get switchButtonLabel() {
    this.hidden || this.#notImplemented();
  }

  /**
   * @returns {string} Icon for the switch button. Obsolete when panel is hidden.
   */
  get switchButtonIcon() {
    this.hidden || this.#notImplemented();
  }

  /**
   * @returns {string} Default path to panel. Obsolete when panel is hidden.
   */
  get switchButtonDefaultUrl() {
    this.hidden || this.#notImplemented();
  }

  /**
   * @returns {boolean} Controls whether the panel will display a header
   */
  get displayHeader() {
    return false;
  }

  get expandActiveSection() {
    return false;
  }

  get scrollActiveLinkIntoView() {
    return false;
  }

  #notImplemented() {
    throw "not implemented";
  }
}
