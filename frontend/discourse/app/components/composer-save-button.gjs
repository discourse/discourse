import Component from "@glimmer/component";
import { service } from "@ember/service";
import { formatShortcut } from "discourse/lib/shortcut-format";
import { applyValueTransformer } from "discourse/lib/transformer";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

export default class ComposerSaveButton extends Component {
  @service capabilities;

  shortcut = formatShortcut("mod+enter");

  get translatedTitle() {
    if (!this.capabilities.hasKeyboard) {
      return;
    }
    return i18n("composer.submit_shortcut_title", {
      shortcut: this.shortcut.label,
    });
  }

  get label() {
    return applyValueTransformer("composer-save-button-label", this.args.label);
  }

  <template>
    <DButton
      aria-keyshortcuts={{if this.capabilities.hasKeyboard this.shortcut.aria}}
      class={{dConcatClass "btn-primary create" (if @disableSubmit "disabled")}}
      ...attributes
      @action={{@action}}
      @forwardEvent={{@forwardEvent}}
      @icon={{@icon}}
      @label={{this.label}}
      @translatedTitle={{this.translatedTitle}}
    />
  </template>
}
