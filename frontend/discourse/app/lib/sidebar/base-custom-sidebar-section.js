/**
 * Base class representing a sidebar section header interface.
 */
export default class BaseCustomSidebarSection {
  /**
   * @returns {string} The name of the section header. Needs to be dasherized and lowercase.
   */
  get name() {
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
   *
   * @example
   * // Return multiple actions for a dropdown menu
   * get actions() {
   *   return [
   *     {
   *       id: "edit",
   *       title: "Edit Section",
   *       action: () => this.editSection()
   *     },
   *     {
   *       id: "add",
   *       title: "Add Item",
   *       action: () => this.addItem()
   *     },
   *     {
   *       id: "refresh",
   *       title: "Refresh",
   *       action: () => this.refresh()
   *     }
   *   ];
   * }
   */
  get actions() {}

  /**
   * @returns {string} Icon for dropdown header options button
   */
  get actionsIcon() {}

  /**
   * @returns {BaseCustomSidebarSectionLink[]} Links for section
   */
  get links() {}

  /**
   * @returns {Boolean} Whether or not to show the entire section including heading.
   */
  get displaySection() {
    return true;
  }

  /**
   * @returns {Boolean} Whether or not to collapse the entire section by default.
   */
  get collapsedByDefault() {
    return false;
  }

  _notImplemented() {
    throw "not implemented";
  }
}
