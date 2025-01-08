import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse-common/helpers/d-icon";
import I18n from "discourse-i18n";
import PluginOutletDebugButton from "./plugin-outlet-debug/button";
import SafeModeButton from "./safe-mode/button";
import devToolsState from "./state";
import VerboseLocalizationButton from "./verbose-localization/button";

export default class Toolbar extends Component {
  @action
  disableDevTools() {
    I18n.disableVerboseLocalizationSession();
    window.disableDevTools();
  }

  <template>
    <div class="dev-tools-toolbar">
      <PluginOutletDebugButton />
      <SafeModeButton />
      <VerboseLocalizationButton />
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
