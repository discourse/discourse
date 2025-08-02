import Component from "@glimmer/component";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import { applyValueTransformer } from "discourse/lib/transformer";
import { translateModKey } from "discourse/lib/utilities";
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
      class={{concatClass "btn-primary create" (if @disableSubmit "disabled")}}
      ...attributes
    />
  </template>
}
