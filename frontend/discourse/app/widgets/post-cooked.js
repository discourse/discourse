/**
 * IMPORTANT: The widget rendering system has been decommissioned.
 *
 * This file is maintained only to prevent breaking imports in existing third-party customizations.
 * New code should not use this component or the widget system.
 */

import { warnWidgetsDecommissioned } from "discourse/widgets/widget";

/**
 * This class is kept only for backward compatibility.
 *
 * @deprecated This class is part of the decommissioned widget system and should not be used anymore.
 */
class PostCooked {
  constructor() {
    warnWidgetsDecommissioned();
  }

  /**
   * @deprecated the widget rendering system was decommissioned
   */
  init() {}

  /**
   * @deprecated the widget rendering system was decommissioned
   */
  update() {}

  /**
   * @deprecated the widget rendering system was decommissioned
   */
  destroy() {}

  /**
   * @deprecated the widget rendering system was decommissioned
   */
  _decorateAndAdopt() {}

  /**
   * @deprecated the widget rendering system was decommissioned
   */
  _applySearchHighlight() {}

  /**
   * @deprecated the widget rendering system was decommissioned
   */
  _showLinkCounts() {}

  /**
   * @deprecated the widget rendering system was decommissioned
   */
  async _toggleQuote() {}

  /**
   * @deprecated the widget rendering system was decommissioned
   */
  _urlForPostNumber() {}

  /**
   * @deprecated the widget rendering system was decommissioned
   */
  _updateQuoteElements() {}

  /**
   * @deprecated the widget rendering system was decommissioned
   */
  _insertQuoteControls() {}

  /**
   * @deprecated the widget rendering system was decommissioned
   */
  _computeCooked() {}

  /**
   * @deprecated the widget rendering system was decommissioned
   */
  _decorateMentions() {}

  /**
   * @deprecated the widget rendering system was decommissioned
   */
  _rerenderUserStatusOnMentions() {}

  /**
   * @deprecated the widget rendering system was decommissioned
   */
  _rerenderUsersStatusOnMentions() {}

  /**
   * @deprecated the widget rendering system was decommissioned
   */
  _extractMentions() {}

  /**
   * @deprecated the widget rendering system was decommissioned
   */
  _trackMentionedUserStatus() {}

  /**
   * @deprecated the widget rendering system was decommissioned
   */
  _stopTrackingMentionedUsersStatus() {}

  /**
   * @deprecated the widget rendering system was decommissioned
   */
  _post() {}
}

export {
  warnWidgetsDecommissioned as addDecorator,
  warnWidgetsDecommissioned as resetDecorators,
  PostCooked as default,
};
