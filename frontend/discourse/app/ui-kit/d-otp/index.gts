import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { trackedArray } from "@ember/reactive/collections";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { isBlank } from "@ember/utils";
import preventScrollOnFocus from "discourse/modifiers/prevent-scroll-on-focus";
import type { CapabilitiesService } from "discourse/services/capabilities";
import { i18n } from "discourse-i18n";
import Slot from "./slot.gts";

const DEFAULT_SLOTS = 6;

interface DOTPSignature {
  Element: HTMLInputElement;

  Args: {
    /** Number of OTP input slots to display (defaults to 6) */
    slots?: number;

    /** The inputmode attribute for the hidden input (defaults to "numeric") */
    inputMode?: string;

    /** The autocomplete attribute for the hidden input (defaults to "one-time-code") */
    autocomplete?: string;

    /** Focus the input automatically unless disabled or on iOS */
    autoFocus?: boolean;

    /** Callback used to normalize typed or pasted input */
    normalizeInput?: (value: string) => string;

    /** Callback fired when the input value changes */
    onChange?: (value: string) => void;

    /** Callback fired when all slots become filled */
    onFill?: (value: string) => void;

    /** Adds a visual separator after every groupSize slots */
    groupSize?: number;
  };
}

export default class DOTP extends Component<DOTPSignature> {
  @service declare capabilities: CapabilitiesService;

  @tracked isFocused = false;
  @tracked isAllSelected = false;

  otp = trackedArray<string>(Array(this.slots).fill(""));

  get slots() {
    return this.args.slots ?? DEFAULT_SLOTS;
  }

  get autoFocus() {
    return (this.args.autoFocus ?? true) && !this.capabilities.isIOS;
  }

  get inputMode() {
    return this.args.inputMode ?? "numeric";
  }

  get autocomplete() {
    return this.args.autocomplete ?? "one-time-code";
  }

  get groupSize() {
    return this.args.groupSize;
  }

  get maxLength() {
    if (!this.groupSize) {
      return this.slots;
    }

    return this.slots + Math.floor((this.slots - 1) / this.groupSize);
  }

  get isFilled() {
    return this.otp.every((char) => !isBlank(char));
  }

  get value() {
    return this.otp.join("");
  }

  normalizeInput(value: string) {
    if (this.args.normalizeInput) {
      return this.args.normalizeInput(value);
    }

    return value.replace(/[^0-9]/g, "");
  }

  @action
  showSeparator(index: number) {
    return (
      this.groupSize &&
      index < this.otp.length - 1 &&
      (index + 1) % this.groupSize === 0
    );
  }

  @action
  focusInput(element: HTMLInputElement) {
    if (!this.autoFocus) {
      return;
    }

    element.autofocus = true;

    requestAnimationFrame(() => {
      if (!element.isConnected) {
        return;
      }

      element.focus({ preventScroll: true });
    });
  }

  @action
  onInput(event: Event) {
    this.#handleInput(event.target as HTMLInputElement);
  }

  @action
  onSelect(event: Event) {
    const input = event.target as HTMLInputElement;
    const hasSelection = input.selectionStart !== input.selectionEnd;
    this.isAllSelected =
      hasSelection &&
      input.selectionStart === 0 &&
      input.selectionEnd === input.value.length;
  }

  @action
  onFocus() {
    this.isFocused = true;
    this.isAllSelected = false;
  }

  @action
  onBlur() {
    this.isFocused = false;
    this.isAllSelected = false;
  }

  @action
  onKeyDown(event: KeyboardEvent) {
    // Disable arrow keys as you can only fill last unfilled or backspace
    if (
      ["ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown"].includes(event.key)
    ) {
      event.preventDefault();
    }
  }

  @action
  onPaste(event: ClipboardEvent) {
    const input = event.target as HTMLInputElement;
    event.preventDefault(); // Prevent the call to input as we manually call it later

    const { clipboardData } = event;
    if (!clipboardData) {
      return;
    }

    const pastedData = clipboardData.getData("text");
    input.value = this.normalizeInput(pastedData);
    this.#handleInput(input);
  }

  @action
  isFocusedSlot(index: number) {
    if (!this.isFocused) {
      return false;
    }

    if (this.isAllSelected) {
      return !isBlank(this.otp[index]);
    }

    const firstEmptyIndex = this.otp.findIndex((char) => isBlank(char));
    return (
      index === (firstEmptyIndex >= 0 ? firstEmptyIndex : this.otp.length - 1)
    );
  }

  #handleInput(input: HTMLInputElement) {
    const chars = this.normalizeInput(input.value)
      .split("")
      .slice(0, this.otp.length);
    const wasFilled = this.isFilled;

    for (let i = 0; i < this.otp.length; i++) {
      this.otp[i] = chars[i] || "";
    }

    const joinedOtp = this.otp.join("");

    input.value = joinedOtp;

    this.args.onChange?.(joinedOtp);

    // Check if just became filled and call callback
    if (!wasFilled && this.isFilled) {
      this.args.onFill?.(joinedOtp);
    }

    this.isAllSelected = false;
  }

  <template>
    <div class="d-otp">
      <div class="d-otp-group">
        {{#each this.otp as |char index|}}
          <Slot
            @char={{char}}
            @index={{index}}
            @isFocused={{this.isFocusedSlot index}}
          />
          {{#if (this.showSeparator index)}}
            <span aria-hidden="true" class="d-otp-separator">-</span>
          {{/if}}
        {{/each}}
      </div>

      <div class="d-otp-input-wrapper">
        <input
          aria-label={{i18n "d_otp.screen_reader" count=this.slots}}
          autocapitalize="off"
          autocomplete={{this.autocomplete}}
          autocorrect="off"
          class="d-otp-input"
          data-slot="input-otp"
          inputmode={{this.inputMode}}
          maxlength={{this.maxLength}}
          spellcheck="false"
          ...attributes
          {{preventScrollOnFocus}}
          {{on "input" this.onInput}}
          {{on "select" this.onSelect}}
          {{on "keydown" this.onKeyDown}}
          {{on "focus" this.onFocus}}
          {{on "blur" this.onBlur}}
          {{on "paste" this.onPaste}}
          {{didInsert this.focusInput}}
        />
      </div>
    </div>
  </template>
}
