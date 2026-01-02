import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import devToolsState from "../state";

/**
 * Toggle button for the plugin outlet debug mode in the dev-tools toolbar.
 * Shows plugin outlet boundaries and arg information when active.
 *
 * @component PluginOutletDebugButton
 */
export default class PluginOutletDebugButton extends Component {
  @action
  togglePluginOutlets() {
    devToolsState.pluginOutletDebug = !devToolsState.pluginOutletDebug;
  }

  <template>
    <button
      title={{i18n "dev_tools.toggle_plugin_outlet_debug"}}
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
