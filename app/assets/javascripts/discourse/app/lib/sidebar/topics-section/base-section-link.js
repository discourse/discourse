/**
 * Base class representing a sidebar topics section link interface.
 */
export default class BaseSectionLink {
  constructor({ topicTrackingState, currentUser } = {}) {
    this.topicTrackingState = topicTrackingState;
    this.currentUser = currentUser;
  }

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
   * @returns {Object} Query parameters for <LinkTo> component. See https://api.emberjs.com/ember/release/classes/Ember.Templates.components/methods/LinkTo?anchor=LinkTo
   */
  get query() {
    return {};
  }

  /**
   * @returns {String} current-when for <LinkTo> component. See https://api.emberjs.com/ember/release/classes/Ember.Templates.components/methods/LinkTo?anchor=LinkTo
   */
  get currentWhen() {}

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
   * @returns {string} Text for the badge within the link
   */
  get badgeText() {}

  _notImplemented() {
    throw "not implemented";
  }
}
