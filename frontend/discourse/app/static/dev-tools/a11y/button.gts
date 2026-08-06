import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { dockState, toggleDockTool } from "discourse/static/dev-tools/dock";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class A11yButton extends Component {
  get active() {
    const state = dockState();
    return state.open && state.activeTool === "a11y";
  }

  @action
  toggle() {
    toggleDockTool("a11y");
  }

  <template>
    <button
      type="button"
      title={{i18n "dev_tools.toggle_a11y"}}
      class={{dConcatClass "toggle-a11y" (if this.active "--active")}}
      {{on "click" this.toggle}}
    >
      {{dIcon "universal-access"}}
    </button>
  </template>
}
