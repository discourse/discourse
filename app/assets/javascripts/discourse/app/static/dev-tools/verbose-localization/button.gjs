import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse-common/helpers/d-icon";
import I18n from "discourse-i18n";

export default class VerboseLocalizationButton extends Component {
  @action
  toggleVerboseLocalization() {
    if (I18n.verbose) {
      I18n.disableVerboseLocalizationSession();
    } else {
      I18n.enableVerboseLocalizationSession();
    }
    window.location.reload();
  }

  <template>
    <button
      title="Toggle verbose localization"
      class={{concatClass
        "toggle-verbose-localization"
        (if I18n.verbose "--active")
      }}
      {{on "click" this.toggleVerboseLocalization}}
    >
      {{icon "scroll"}}
    </button>
  </template>
}
