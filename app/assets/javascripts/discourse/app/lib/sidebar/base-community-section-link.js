import { setOwner } from "@ember/owner";
import { service } from "@ember/service";

/**
 * Base class representing a sidebar communtiy section link interface.
 */
export default class BaseCommunitySectionLink {
  @service currentUser;
  @service appEvents;
  @service router;
  @service siteSettings;
  @service topicTrackingState;

  constructor(owner, { inMoreDrawer, overridenName, overridenIcon } = {}) {
    setOwner(this, owner);
    this.inMoreDrawer = inMoreDrawer;
    this.overridenName = overridenName;
    this.overridenIcon = overridenIcon;
  }

  /**
   * Called when state has changed in the TopicTrackingState service
   */
  onTopicTrackingStateChange() {}

  /**
   * Called when community-section component is torn down.
   */
  teardown() {}

  /**
   * @returns {string} The name of the section link. Needs to be dasherized and lowercase.
   */
  get name() {
    this._notImplemented();
  }

  /**
   * @returns {boolean} Whether the section link should be displayed. Defaults to true.
   */
  get shouldDisplay() {
    return true;
  }

  /**
   * @returns {string|undefined} Ember route
   */
  get route() {}

  /**
   * @returns {string} href attribute for the link. This property will take precedence over the `route` property when set.
   */
  get href() {}

  /**
   * @returns {Object} Model for <LinkTo> component. See https://api.emberjs.com/ember/release/classes/Ember.Templates.components/methods/LinkTo?anchor=LinkTo
   */
  get model() {}

  /**
   * @returns {Object} Models for <LinkTo> component. See https://api.emberjs.com/ember/release/classes/Ember.Templates.components/methods/LinkTo?anchor=LinkTo
   */
  get models() {}

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

  /**
   * @private
   */
  get prefixType() {
    return "icon";
  }

  /**
   * @returns {string} The name of the fontawesome icon to be displayed before the link. Defaults to "link".
   */
  get defaultPrefixValue() {
    return "link";
  }

  /**
   * @returns {string} The name of the fontawesome icon to be displayed before the link.
   */
  get prefixValue() {
    return this.overridenIcon || this.defaultPrefixValue;
  }

  _notImplemented() {
    throw "not implemented";
  }
}
