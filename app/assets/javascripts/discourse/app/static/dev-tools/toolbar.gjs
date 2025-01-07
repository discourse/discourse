import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import icon from "discourse-common/helpers/d-icon";
import devToolsState from "./state";

export default class Toolbar extends Component {
  @action
  toggleSafeMode() {
    const urlParams = new URLSearchParams(window.location.search);
    if (urlParams.has("safe_mode")) {
      urlParams.delete("safe_mode");
    } else {
      urlParams.set("safe_mode", "no_themes,no_plugins");
    }
    window.location.search = urlParams.toString();
  }

  @action
  togglePluginOutlets() {
    devToolsState.pluginOutletDebug = !devToolsState.pluginOutletDebug;
  }

  @action
  disableDevTools() {
    window.disableDevTools();
  }

  <template>
    <div class="dev-tools-toolbar">
      <button
        title="Toggle plugin outlet debug"
        class="toggle-plugin-outlets"
        {{on "click" this.togglePluginOutlets}}
      >
        {{icon "plug"}}
      </button>
      <button
        title="Toggle safe mode"
        class="toggle-safe-mode"
        {{on "click" this.toggleSafeMode}}
      >
        {{icon "truck-medical"}}
      </button>
      <button
        title="Disable dev tools"
        class="disable-dev-tools"
        {{on "click" this.disableDevTools}}
      >
        {{icon "xmark"}}
      </button>
    </div>
  </template>
}
