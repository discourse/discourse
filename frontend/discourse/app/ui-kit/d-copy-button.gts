import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { modifier } from "ember-modifier";
import discourseDebounce from "discourse/lib/debounce";
import { bind } from "discourse/lib/decorators";
import { clipboardCopy } from "discourse/lib/utilities";
import DButton from "discourse/ui-kit/d-button";

interface DCopyButtonSignature {
  Args: {
    /** The text to copy. Without it, the button copies the content of `@selector`. */
    value?: string;

    /** A selector for the element whose value or text to copy. */
    selector?: string;

    /** The ID of the button icon. Defaults to `copy`. */
    icon?: string;

    /** The class of the button. Defaults to `btn-primary`. */
    copyClass?: string;

    /** The label of the button, already translated. */
    translatedLabel?: string;

    /** The label shown, and announced, after a copy. */
    translatedLabelAfterCopy?: string;

    /** The accessible name of the button. */
    ariaLabel?: string;

    /** Called after the text is copied. */
    copied?: () => void;

    /** Shows the copied state when it turns true, for copies made elsewhere. */
    isCopied?: boolean;
  };
}

export default class DCopyButton extends Component<DCopyButtonSignature> {
  @tracked showCopied = false;

  watchExternalCopy = modifier((_: Element, [isCopied]: [boolean?]) => {
    if (isCopied && !this._wasCopied) {
      this._showCopied();
    }

    this._wasCopied = isCopied;
  });

  declare _wasCopied: boolean | undefined;

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

      value = (target as HTMLInputElement).value ?? target.textContent;
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
    if (this.isDestroying) {
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
