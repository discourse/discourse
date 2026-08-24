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
   * Links rendered behind a "more" drawer instead of directly in the section,
   * matching the drawer the community section uses.
   *
   * @returns {BaseCustomSidebarSectionLink[]} Links for the drawer
   */
  get moreLinks() {
    return [];
  }

  /**
   * @returns {string} Text for the drawer trigger. Defaults to "More…".
   */
  get moreLinksTriggerText() {}

  /**
   * @returns {string} Prefix type for the drawer trigger, matching a section
   * link's. Accepted values: icon, image, text, emoji, square.
   */
  get moreLinksTriggerPrefixType() {}

  /**
   * @returns {string} Prefix value for the drawer trigger. Defaults to an
   * ellipsis icon.
   */
  get moreLinksTriggerPrefixValue() {}

  /**
   * @returns {string} Suffix type for the drawer trigger. Accepted value: icon.
   */
  get moreLinksTriggerSuffixType() {}

  /**
   * @returns {string} Suffix value for the drawer trigger, e.g. a chevron when
   * the trigger reads as a picker.
   */
  get moreLinksTriggerSuffixValue() {}

  /**
   * Renders the drawer's links directly in the section instead of behind the
   * trigger, for a section that wants them listed but kept apart from its own
   * links.
   *
   * @returns {boolean} Defaults to false.
   */
  get moreLinksInline() {
    return false;
  }

  /**
   * Whether the drawer's active link is lifted out and rendered above the
   * trigger. Turn this off when the trigger itself names the current choice.
   *
   * @returns {boolean} Defaults to true.
   */
  get moreLinksHoistActiveLink() {
    return true;
  }

  /**
   * @returns {"start"|"end"} Whether the drawer leads or trails the section's
   * own links. Defaults to "end".
   */
  get moreLinksPosition() {
    return "end";
  }

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
