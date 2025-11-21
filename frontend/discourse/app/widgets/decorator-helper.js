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
export default class DecoratorHelper {
  constructor() {
    warnWidgetsDecommissioned();
  }

  /**
   * @deprecated the widget rendering system was decommissioned
   */
  attach() {}

  /**
   * @deprecated the widget rendering system was decommissioned
   */
  get model() {}

  /**
   * @deprecated the widget rendering system was decommissioned
   */
  getModel() {}

  /**
   * @deprecated the widget rendering system was decommissioned
   */
  rawHtml() {}

  /**
   * @deprecated the widget rendering system was decommissioned
   */
  cooked() {}

  /**
   * @deprecated the widget rendering system was decommissioned
   */
  connect() {}

  /**
   * @deprecated the widget rendering system was decommissioned
   */
  renderGlimmer() {}
}
