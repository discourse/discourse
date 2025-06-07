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
   * @returns {BaseCustomSidebarSectionLink[]} Links for the "More..." dropdown section
   */
  get moreLinks() {}

  /**
   * @returns {string} Text for the "More..." dropdown toggle (defaults to "More...")
   */
  get moreSectionText() {}

  /**
   * @returns {string} Icon for the "More..." dropdown toggle (defaults to "chevron-down")
   */
  get moreSectionIcon() {}

  /**
   * @returns {Function} Action for the "More..." section button
   */
  get moreSectionButtonAction() {}

  /**
   * @returns {string} Text for the "More..." section button
   */
  get moreSectionButtonText() {}

  /**
   * @returns {string} Icon for the "More..." section button
   */
  get moreSectionButtonIcon() {}

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
