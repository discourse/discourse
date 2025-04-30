import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import DButton from "discourse/components/d-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import concatClass from "discourse/helpers/concat-class";
import { translateModKey } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

export default class ComposerSaveButton extends Component {
  get translatedTitle() {
    return i18n("composer.title", { modifier: translateModKey("Meta+") });
  }

  <template>
    <PluginOutlet
      @name="composer-save-button"
      @outletArgs={{hash
        action=@action
        forwardEvent=@forwardEvent
        disableSubmit=@disableSubmit
      }}
    >
      <DButton
        @action={{@action}}
        @label={{@label}}
        @icon={{@icon}}
        @translatedTitle={{this.translatedTitle}}
        @forwardEvent={{@forwardEvent}}
        class={{concatClass
          "btn-primary create"
          (if @disableSubmit "disabled")
        }}
        ...attributes
      />
    </PluginOutlet>
  </template>
}
