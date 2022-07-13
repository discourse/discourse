/**
 * Base class representing a sidebar section link interface.
 */
export default class BaseCustomSidebarSectionLink {
  /**
   * @returns {string} The name of the section link. Needs to be dasherized and lowercase.
   */
  get name() {
    this._notImplemented();
  }

  /**
   * @returns {string} Ember route
   */
  get route() {
    this._notImplemented();
  }

  /**
   * @returns {Object} Model for <LinkTo> component. See https://api.emberjs.com/ember/release/classes/Ember.Templates.components/methods/LinkTo?anchor=LinkTo
   */
  get model() {}

  /**
   * @returns {string} Title for the link
   */
  get title() {
    this._notImplemented();
  }

  /**
   * @returns {string} Text for the link
   */
  get text() {
    this._notImplemented();
  }

  /**
   * @returns {string} Prefix icon for the link
   */
  get prefixIcon() {}

  /**
   * @returns {string} Prefix icon hex color
   */
  get prefixIconColor() {}

  /**
   * @returns {string} Badge icon for prefix icon
   */
  get prefixIconBadge() {}

  /**
   * @returns {string} Suffix icon for the link
   */
  get SuffixIcon() {}

  /**
   * @returns {string} CSS class for suffix icon
   */
  get SuffixCSSClass() {}

  _notImplemented() {
    throw "not implemented";
  }
}
