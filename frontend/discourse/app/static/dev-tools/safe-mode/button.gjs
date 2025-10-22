import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";

export default class PluginOutletDebugButton extends Component {
  get safeModeActive() {
    return new URLSearchParams(window.location.search).has("safe_mode");
  }

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

  <template>
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
  </template>
}
