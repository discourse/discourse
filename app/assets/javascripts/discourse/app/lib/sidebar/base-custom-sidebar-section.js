/**
 * Base class representing a sidebar section header interface.
 */
export default class BaseCustomSidebarSection {
  constructor({ sidebar } = {}) {
    this.sidebar = sidebar;
  }

  /**
   * Called when sidebar component is torn down.
   */
  teardown() {}

  /**
   * @returns {string} The name of the section header. Needs to be dasherized and lowercase.
   */
  get name() {
    this._notImplemented();
  }

  /**
   * @returns {string} Title for the header
   */
  get title() {
    this._notImplemented();
  }

  /**
   * @returns {string} Text for the header
   */
  get text() {
    this._notImplemented();
  }

  /**
   * @returns {Array} Actions for header options button
   */
  get actions() {}

  /**
   * @returns {string} Icon for header options button
   */
  get actionsIcon() {}

  /**
   * @returns {BaseCustomSidebarSectionLink[]} Links for section
   */
  get links() {}

  _notImplemented() {
    throw "not implemented";
  }
}
