import Component from "@glimmer/component";
import { applyValueTransformer } from "discourse/lib/transformer";
import { translateModKey } from "discourse/lib/utilities";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

export default class ComposerSaveButton extends Component {
  get translatedTitle() {
    return i18n("composer.title", { modifier: translateModKey("Meta+") });
  }

  get label() {
    return applyValueTransformer("composer-save-button-label", this.args.label);
  }

  <template>
    <DButton
      @action={{@action}}
      @label={{this.label}}
      @icon={{@icon}}
      @translatedTitle={{this.translatedTitle}}
      @forwardEvent={{@forwardEvent}}
      class={{dConcatClass "btn-primary create" (if @disableSubmit "disabled")}}
      aria-keyshortcuts={{translateModKey "Meta+Enter" "+"}}
      ...attributes
    />
  </template>
}
