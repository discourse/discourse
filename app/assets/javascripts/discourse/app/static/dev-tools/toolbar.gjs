import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse-common/helpers/d-icon";
import I18n from "discourse-i18n";
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
    I18n.disableVerboseLocalizationSession();
    window.disableDevTools();
  }

  @action
  toggleVerboseLocalization() {
    if (I18n.verbose) {
      I18n.disableVerboseLocalizationSession();
    } else {
      I18n.enableVerboseLocalizationSession();
    }
    window.location.reload();
  }

  get safeModeActive() {
    return new URLSearchParams(window.location.search).has("safe_mode");
  }

  get verboseLocalizationActive() {
    return I18n.verbose;
  }

  get pluginOutletDebugActive() {
    return devToolsState.pluginOutletDebug;
  }

  <template>
    <div class="dev-tools-toolbar">
      <button
        title="Toggle plugin outlet debug"
        class={{concatClass
          "toggle-plugin-outlets"
          (if this.pluginOutletDebugActive "--active")
        }}
        {{on "click" this.togglePluginOutlets}}
      >
        {{icon "plug"}}
      </button>
      <button
        title="Toggle safe mode"
        class={{concatClass
          "toggle-safe-mode"
          (if this.safeModeActive "--active")
        }}
        {{on "click" this.toggleSafeMode}}
      >
        {{icon "truck-medical"}}
      </button>
      <button
        title="Toggle verbose localization"
        class={{concatClass
          "toggle-verbose-localization"
          (if this.verboseLocalizationActive "--active")
        }}
        {{on "click" this.toggleVerboseLocalization}}
      >
        {{icon "scroll"}}
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
