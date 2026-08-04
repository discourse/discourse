import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { dockState, toggleDockTool } from "discourse/static/dev-tools/dock";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const TOOL_ID = "message-bus";

/** Toolbar entry for the MessageBus inspector. */
export default class MessageBusButton extends Component {
  get isActive() {
    const state = dockState();
    return state.open && state.activeTool === TOOL_ID;
  }

  @action
  toggle() {
    toggleDockTool(TOOL_ID);
  }

  <template>
    <button
      type="button"
      title={{i18n "dev_tools.toggle_message_bus"}}
      class={{dConcatClass "toggle-message-bus" (if this.isActive "--active")}}
      {{on "click" this.toggle}}
    >
      {{dIcon "tower-broadcast"}}
    </button>
  </template>
}
