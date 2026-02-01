/**
 * IMPORTANT: The widget rendering system has been decommissioned.
 *
 * This file is maintained only to prevent breaking imports in existing third-party customizations.
 * New code should not use this component or the widget system.
 */

/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import { warnWidgetsDecommissioned } from "discourse/widgets/widget";

export {
  warnWidgetsDecommissioned as addWidgetCleanCallback,
  warnWidgetsDecommissioned as removeWidgetCleanCallback,
  warnWidgetsDecommissioned as resetWidgetCleanCallbacks,
} from "discourse/widgets/widget";

@tagName("")
export default class MountWidget extends Component {
  init() {
    super.init(...arguments);
    warnWidgetsDecommissioned();
  }

  <template>
    <div ...attributes>
      {{! No-op. The widget rendering system was decommissioned }}
    </div>
  </template>
}
