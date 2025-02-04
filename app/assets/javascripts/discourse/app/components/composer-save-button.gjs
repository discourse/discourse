import Component from "@glimmer/component";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import { translateModKey } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

export default class ComposerSaveButton extends Component {
  get translatedTitle() {
    return i18n("composer.title", { modifier: translateModKey("Meta+") });
  }

  <template>
    <DButton
      @action={{@action}}
      @label={{@label}}
      @icon={{@icon}}
      @translatedTitle={{this.translatedTitle}}
      @forwardEvent={{@forwardEvent}}
      class={{concatClass "btn-primary create" (if @disabledSubmit "disabled")}}
      ...attributes
    />
  </template>
}
