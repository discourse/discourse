import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import devToolsState from "../state";

/**
 * Toggle button for the plugin outlet debug mode in the dev-tools toolbar.
 * Shows plugin outlet boundaries and arg information when active.
 */
export default class PluginOutletDebugButton extends Component {
  @action
  togglePluginOutlets() {
    devToolsState.pluginOutletDebug = !devToolsState.pluginOutletDebug;
  }

  <template>
    <button
      title={{i18n "dev_tools.toggle_plugin_outlet_debug"}}
      class={{dConcatClass
        "toggle-plugin-outlets"
        (if devToolsState.pluginOutletDebug "--active")
      }}
      {{on "click" this.togglePluginOutlets}}
    >
      {{dIcon "plug"}}
    </button>
  </template>
}
