import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import devToolsState from "../state";
import MessageBusPanel from "./panel";

const TOOL_ID = "message-bus";

/**
 * Toolbar entry for the MessageBus inspector.
 *
 * Whether the panel is open is stored through the developer tools state rather
 * than held here, so it survives the toolbar re-rendering and is restored on a
 * page refresh like the other tools' settings.
 *
 * The panel renders from here rather than from the toolbar so that it inherits
 * the toolbar's stacking context: `DDockPanel` deliberately sets no `z-index`
 * of its own, leaving that to whatever uses it.
 */
export default class MessageBusButton extends Component {
  get isOpen() {
    return devToolsState.getFlag(TOOL_ID, "open") ?? false;
  }

  @action
  toggle() {
    devToolsState.setFlag(TOOL_ID, "open", !this.isOpen);
  }

  @action
  close() {
    devToolsState.setFlag(TOOL_ID, "open", false);
  }

  <template>
    <button
      type="button"
      title={{i18n "dev_tools.toggle_message_bus"}}
      class={{dConcatClass "toggle-message-bus" (if this.isOpen "--active")}}
      {{on "click" this.toggle}}
    >
      {{dIcon "tower-broadcast"}}
    </button>

    <MessageBusPanel @isOpen={{this.isOpen}} @onClose={{this.close}} />
  </template>
}
