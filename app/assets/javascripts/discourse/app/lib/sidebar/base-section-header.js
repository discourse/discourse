/**
 * Base class representing a sidebar section header interface.
 */
export default class BaseSectionHeader {
  constructor({ currentUser, appEvents } = {}) {
    this.currentUser = currentUser;
    this.appEvents = appEvents;
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
   * @returns {string} Ember route
   */
  get route() {
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

  _notImplemented() {
    throw "not implemented";
  }
}
