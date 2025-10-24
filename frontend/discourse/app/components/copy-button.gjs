/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { action } from "@ember/object";
import { tagName } from "@ember-decorators/component";
import DButton from "discourse/components/d-button";
import discourseDebounce from "discourse/lib/debounce";
import { bind } from "discourse/lib/decorators";

@tagName("")
export default class CopyButton extends Component {
  copyIcon = "copy";
  copyClass = "btn-primary";

  init() {
    super.init(...arguments);

    this.copyTranslatedLabel = this.translatedLabel;
  }

  @bind
  _restoreButton() {
    if (this.isDestroying || this.isDestroyed) {
      return;
    }

    this.set("copyIcon", "copy");
    this.set("copyClass", "btn-primary");
    this.set("copyTranslatedLabel", this.translatedLabel);
  }

  @action
  copy() {
    const target = document.querySelector(this.selector);
    target.select();
    target.setSelectionRange(0, target.value.length);

    try {
      document.execCommand("copy");

      if (this.copied) {
        this.copied();
      }

      this.set("copyIcon", "check");
      this.set("copyClass", "btn-primary ok");
      this.set("copyTranslatedLabel", this.translatedLabelAfterCopy);

      discourseDebounce(this._restoreButton, 3000);
    } catch {}
  }

  <template>
    <DButton
      @icon={{this.copyIcon}}
      @action={{this.copy}}
      class="copy-button {{this.copyClass}}"
      @ariaLabel={{this.ariaLabel}}
      @translatedLabel={{this.copyTranslatedLabel}}
    />
  </template>
}
