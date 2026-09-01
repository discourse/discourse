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

  get copyTranslatedLabel() {
    return this.showCopied
      ? this.args.translatedLabelAfterCopy
      : this.args.translatedLabel;
  }

  get announcement() {
    return this.showCopied ? this.args.translatedLabelAfterCopy : "";
  }

  @action
  async copy() {
    let value = this.args.value;

    if (value === undefined) {
      if (!this.args.selector) {
        return;
      }

      const target = document.querySelector(this.args.selector);
      if (!target) {
        return;
      }

      value = target.value ?? target.textContent;
    }

    if (value == null) {
      return;
    }

    try {
      await clipboardCopy(value);
      this.args.copied?.();
      this._showCopied();
    } catch {}
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

  <template>
    <DButton
      class="copy-button {{this.copyClass}}"
      @action={{this.copy}}
      @ariaLabel={{@ariaLabel}}
      @icon={{this.copyIcon}}
      @translatedLabel={{this.copyTranslatedLabel}}
    />
    <span
      aria-live="polite"
      class="sr-only"
      {{this.watchExternalCopy @isCopied}}
    >{{this.announcement}}</span>
  </template>
}
