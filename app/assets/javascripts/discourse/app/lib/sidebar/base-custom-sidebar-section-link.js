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
   * @returns {string} The classnames of the section link.
   */
  get classNames() {
    return "";
  }

  /**
   * @returns {string} The Ember route which the section link should link to.
   */
  get route() {
    this._notImplemented();
  }

  /**
   * @returns {Object} `model` argument for the <LinkTo> component. See https://api.emberjs.com/ember/release/classes/Ember.Templates.components/methods/LinkTo?anchor=LinkTo.
   */
  get model() {}

  /**
   * @returns {Object[]} `models` argument for the <LinkTo> component. See https://api.emberjs.com/ember/release/classes/Ember.Templates.components/methods/LinkTo?anchor=LinkTo.
   */
  get models() {}

  /**
   * @returns {boolean} `current-when` argument for the <LinkTo> component. See See https://api.emberjs.com/ember/release/classes/Ember.Templates.components/methods/LinkTo?anchor=LinkTo.
   */
  get currentWhen() {}

  /**
   * @returns {string} Title for the section link
   */
  get title() {
    this._notImplemented();
  }

  /**
   * @returns {string} Text for the section link
   */
  get text() {
    this._notImplemented();
  }

  /**
   * @returns {string} CSS class for the content text
   */
  get contentCSSClass() {}

  /**
   * @returns {string} Prefix type for the link. Accepted value: icon, image, text
   */
  get prefixType() {}

  /**
   * @returns {string} Prefix value for the link. Accepted value: icon name, image url, text
   */
  get prefixValue() {}

  /**
   * @returns {string} Prefix hex color
   */
  get prefixColor() {}

  /**
   * @returns {string} Prefix badge icon
   */
  get prefixBadge() {}

  /**
   * @returns {string} CSS class for prefix
   */
  get prefixCSSClass() {}

  /**
   * @returns {string} Suffix type for the link. Accepted value: icon
   */
  get suffixType() {}

  /**
   * @returns {string} Suffix value for the link. Accepted value: icon name
   */
  get suffixValue() {}

  /**
   * @returns {string} CSS class for suffix
   */
  get suffixCSSClass() {}

  /**
   * @returns {string} Type of the hover button. Accepted value: icon
   */
  get hoverType() {}

  /**
   * @returns {string} Value for the hover button. Accepted value: icon name
   */
  get hoverValue() {}

  /**
   * @returns {Function} Action for hover button
   */
  get hoverAction() {}

  /**
   * @returns {string} Title attribute for the hover button
   */
  get hoverTitle() {}

  _notImplemented() {
    throw "not implemented";
  }
}
