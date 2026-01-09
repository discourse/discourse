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
 */ export default class WidgetGlue {
  constructor() {
    warnWidgetsDecommissioned();
  }

  /**
   * @deprecated the widget rendering system was decommissioned
   */
  appendTo() {}

  /**
   * @deprecated the widget rendering system was decommissioned
   */
  queueRerender() {}

  /**
   * @deprecated the widget rendering system was decommissioned
   */
  rerenderWidget() {}

  /**
   * @deprecated the widget rendering system was decommissioned
   */
  cleanUp() {}
}
