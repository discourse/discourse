import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { modifier } from "ember-modifier";
import discourseDebounce from "discourse/lib/debounce";
import { bind } from "discourse/lib/decorators";
import { clipboardCopy } from "discourse/lib/utilities";
import DButton from "discourse/ui-kit/d-button";

export default class DCopyButton extends Component {
  @tracked showCopied = false;

  watchExternalCopy = modifier((_, [isCopied]) => {
    if (isCopied && !this._wasCopied) {
      this._showCopied();
    }

    this._wasCopied = isCopied;
  });

  get copyIcon() {
    return this.showCopied ? "check" : this.args.icon || "copy";
  }

  get copyClass() {
    const baseClass = this.args.copyClass || "btn-primary";
    return this.showCopied ? `${baseClass} ok` : baseClass;
  }

  get copyLabel() {
    return this.showCopied ? "user.invited.link_copied" : this.args.label;
  }

  get copyTranslatedLabel() {
    return this.showCopied
      ? this.args.translatedLabelAfterCopy
      : this.args.translatedLabel;
  }

  get announcement() {
    return this.showCopied ? this.args.translatedLabelAfterCopy : "";
  }

  _showCopied() {
    this.showCopied = true;

    discourseDebounce(this._restoreButton, 3000);
  }

  @bind
  _restoreButton() {
    if (this.isDestroying || this.isDestroyed) {
      return;
    }

    this.showCopied = false;
  }

  @action
  async copy() {
    const target = document.querySelector(this.args.selector);

    if (!target) {
      return;
    }

    try {
      await clipboardCopy(target.value ?? target.textContent);
      this.args.copied?.();
      this._showCopied();
    } catch {}
  }

  <template>
    <DButton
      @icon={{this.copyIcon}}
      @action={{this.copy}}
      class="copy-button {{this.copyClass}}"
      @ariaLabel={{@ariaLabel}}
      @label={{this.copyLabel}}
      @translatedLabel={{this.copyTranslatedLabel}}
    />
    <span
      class="sr-only"
      aria-live="polite"
      {{this.watchExternalCopy @isCopied}}
    >{{this.announcement}}</span>
  </template>
}
