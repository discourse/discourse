import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import {
  isValidHex,
  normalizeHex,
  resolveColor,
} from "discourse/lib/color-transformations";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const BLACK = "#000000";

/** Perceived lightness of a 6-digit hex color, from 0 (black) to 1 (white). */
function luminance(hex: string) {
  const r = parseInt(hex.slice(0, 2), 16);
  const g = parseInt(hex.slice(2, 4), 16);
  const b = parseInt(hex.slice(4, 6), 16);
  return (0.299 * r + 0.587 * g + 0.114 * b) / 255;
}

function withoutHash(value: string) {
  return value.replace(/^#/, "");
}

interface DColorInputSignature {
  Args: {
    /** The color, as hex with or without its `#`, or a color name when `allowNamedColors` is set. */
    value?: string | null;

    /**
     * Called with what was typed, picked or pasted, without a leading `#`. Hex comes in uppercase,
     * except text typed into a field that takes names, which comes as typed.
     */
    onChange: (value: string) => void;

    /** Whether both the text field and the picker are disabled. */
    disabled?: boolean;

    /** Whether color names are accepted: lifts the 6-character cap and lets the picker resolve them. */
    allowNamedColors?: boolean;

    /** Whether to show a `#` before the text field. */
    hashPrefix?: boolean;
  };

  /** The text field, which takes the caller's `id`, `name`, `aria-*` and modifiers. */
  Element: HTMLInputElement;
}

/**
 * A color typed as text beside the browser's color picker. It is controlled: it shows `@value` and
 * reports every change through `@onChange`, leaving storage format and validation to the caller.
 */
export default class DColorInput extends Component<DColorInputSignature> {
  /** Hex shows in uppercase; a field taking names shows what it holds, so a name being typed is left alone. */
  get bareValue() {
    const value = withoutHash(this.args.value ?? "");
    return this.args.allowNamedColors ? value : value.toUpperCase();
  }

  get maxLength() {
    return this.args.allowNamedColors ? undefined : 6;
  }

  /** The icon over the picker contrasts with the color the picker shows. */
  get pickerIconClass() {
    return luminance(this.pickerValue.slice(1)) > 0.5
      ? "--is-light"
      : "--is-dark";
  }

  get pickerValue() {
    const value = this.bareValue;
    if (!value) {
      return BLACK;
    }
    if (isValidHex(value)) {
      return `#${normalizeHex(value)}`;
    }
    if (this.args.allowNamedColors) {
      // A fill style set from a string reads back as a string.
      const resolved = resolveColor(value);
      return typeof resolved === "string" ? resolved : BLACK;
    }
    return BLACK;
  }

  /**
   * A pasted color replaces the field; other text goes in at the cursor, as much as fits. Either
   * way it then counts as typed.
   */
  @action
  handlePaste(event: ClipboardEvent) {
    event.preventDefault();
    const input = event.target as HTMLInputElement;
    const pasted = this.#typed(
      withoutHash((event.clipboardData?.getData("text/plain") ?? "").trim())
    );

    if (isValidHex(pasted)) {
      input.value = pasted;
    } else {
      const start = input.selectionStart ?? input.value.length;
      const end = input.selectionEnd ?? start;
      const room =
        (this.maxLength ?? Infinity) - (input.value.length - (end - start));
      const fitted = pasted.slice(0, Math.max(room, 0));
      input.value =
        input.value.slice(0, start) + fitted + input.value.slice(end);
      input.setSelectionRange(start + fitted.length, start + fitted.length);
    }

    this.args.onChange(input.value);
  }

  @action
  handlePickerInput(event: Event) {
    this.args.onChange(
      withoutHash((event.target as HTMLInputElement).value).toUpperCase()
    );
  }

  @action
  handleTextInput(event: Event) {
    const input = event.target as HTMLInputElement;
    const typed = this.#typed(input.value);
    if (typed !== input.value) {
      // Rewritten in place, so the caret stays where the user is typing.
      const { selectionStart, selectionEnd } = input;
      input.value = typed;
      input.setSelectionRange(selectionStart, selectionEnd);
    }
    this.args.onChange(typed);
  }

  /** Typed text in the case the field shows: uppercase hex, or as typed where names are taken. */
  #typed(value: string) {
    return this.args.allowNamedColors ? value : value.toUpperCase();
  }

  <template>
    <div class="d-color-input">
      {{#if @hashPrefix}}
        <span class="d-color-input__prefix">#</span>
      {{/if}}
      <input
        class="d-color-input__hex"
        disabled={{@disabled}}
        maxlength={{this.maxLength}}
        type="text"
        value={{this.bareValue}}
        ...attributes
        {{on "input" this.handleTextInput}}
        {{on "paste" this.handlePaste}}
      />
      <span
        class={{dConcatClass
          "d-color-input__picker-wrapper"
          this.pickerIconClass
        }}
      >
        <input
          aria-label={{i18n "color_input.picker"}}
          class="d-color-input__picker"
          disabled={{@disabled}}
          type="color"
          value={{this.pickerValue}}
          {{on "input" this.handlePickerInput}}
        />
        {{dIcon "eye-dropper"}}
      </span>
    </div>
  </template>
}
