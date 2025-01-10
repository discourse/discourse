import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse-common/helpers/d-icon";
import devToolsState from "../state";

export default class PluginOutletDebugButton extends Component {
  @action
  togglePluginOutlets() {
    devToolsState.pluginOutletDebug = !devToolsState.pluginOutletDebug;
  }

  <template>
    <button
      title="Toggle plugin outlet debug"
      class={{concatClass
        "toggle-plugin-outlets"
        (if devToolsState.pluginOutletDebug "--active")
      }}
      {{on "click" this.togglePluginOutlets}}
    >
      {{icon "plug"}}
    </button>
  </template>
}
