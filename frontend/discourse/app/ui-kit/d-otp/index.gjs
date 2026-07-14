// @ts-check
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { trackedArray } from "@ember/reactive/collections";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { isBlank } from "@ember/utils";
import preventScrollOnFocus from "discourse/modifiers/prevent-scroll-on-focus";
import { i18n } from "discourse-i18n";
import Slot from "./slot";

const DEFAULT_SLOTS = 6;

/**
 * @typedef DOTPSignature
 *
 * @property {HTMLInputElement} Element
 * @property {object} Args
 *
 * @property {number} [Args.slots] - Number of OTP input slots to display (defaults to 6)
 * @property {string} [Args.inputMode] - The inputmode attribute for the hidden input (defaults to "numeric")
 * @property {string} [Args.autocomplete] - The autocomplete attribute for the hidden input (defaults to "one-time-code")
 * @property {boolean} [Args.autoFocus] - Focus the input automatically unless disabled or on iOS
 * @property {function(string): string} [Args.normalizeInput] - Callback used to normalize typed or pasted input
 * @property {function(string): void} [Args.onChange] - Callback fired when the input value changes
 * @property {function(string): void} [Args.onFill] - Callback fired when all slots become filled
 * @property {number} [Args.groupSize] - Adds a visual separator after every groupSize slots
 *
 */

/** @extends {Component<DOTPSignature>} */
export default class DOTP extends Component {
  /**
   * @type {import("discourse/services/capabilities").Capabilities}
   */
  // @ts-ignore (incorrect no-initialization error)
  @service capabilities;

  @tracked isFocused = false;
  @tracked isAllSelected = false;

  otp = trackedArray(Array(this.slots).fill(""));

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

  normalizeInput(value) {
    if (this.args.normalizeInput) {
      return this.args.normalizeInput(value);
    }

    return value.replace(/[^0-9]/g, "");
  }

  @action
  showSeparator(index) {
    return (
      this.groupSize &&
      index < this.otp.length - 1 &&
      (index + 1) % this.groupSize === 0
    );
  }

  get isFilled() {
    return this.otp.every((char) => !isBlank(char));
  }

  get value() {
    return this.otp.join("");
  }

  @action
  focusInput(element) {
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

  /**
   * @param {Event} event
   */
  @action
  onInput(event) {
    const chars = this.normalizeInput(
      /** @type(HTMLInputElement) */ (event.target).value
    )
      .split("")
      .slice(0, this.otp.length);
    const wasFilled = this.isFilled;

    for (let i = 0; i < this.otp.length; i++) {
      this.otp[i] = chars[i] || "";
    }

    const joinedOtp = this.otp.join("");

    /** @type(HTMLInputElement) */ (event.target).value = joinedOtp;

    this.args.onChange?.(joinedOtp);

    // Check if just became filled and call callback
    if (!wasFilled && this.isFilled) {
      this.args.onFill?.(joinedOtp);
    }

    this.isAllSelected = false;
  }

  /**
   * @param {Event} event
   */
  @action
  onSelect(event) {
    const input = /** @type {HTMLInputElement} */ (event.target);
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

  /**
   * @param {KeyboardEvent} event
   */
  @action
  onKeyDown(event) {
    // Disable arrow keys as you can only fill last unfilled or backspace
    if (
      ["ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown"].includes(event.key)
    ) {
      event.preventDefault();
    }
  }

  /**
   * @param {ClipboardEvent} event
   */
  @action
  onPaste(event) {
    const input = /** @type {HTMLInputElement} */ (event.target);
    event.preventDefault(); // Prevent the call to input as we manually call it later

    const { clipboardData } = event;
    if (!clipboardData) {
      return;
    }

    const pastedData = clipboardData.getData("text");
    input.value = this.normalizeInput(pastedData);
    // @ts-ignore
    this.onInput({ target: input });
  }

  /**
   * @param {number} index
   */
  @action
  isFocusedSlot(index) {
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

  <template>
    <div class="d-otp">
      <div class="d-otp-group">
        {{#each this.otp as |char index|}}
          <Slot
            @index={{index}}
            @char={{char}}
            @isFocused={{this.isFocusedSlot index}}
          />
          {{#if (this.showSeparator index)}}
            <span class="d-otp-separator" aria-hidden="true">-</span>
          {{/if}}
        {{/each}}
      </div>

      <div class="d-otp-input-wrapper">
        <input
          {{preventScrollOnFocus}}
          inputmode={{this.inputMode}}
          autocomplete={{this.autocomplete}}
          spellcheck="false"
          autocorrect="off"
          autocapitalize="off"
          data-slot="input-otp"
          class="d-otp-input"
          maxlength={{this.maxLength}}
          {{on "input" this.onInput}}
          {{on "select" this.onSelect}}
          {{on "keydown" this.onKeyDown}}
          {{on "focus" this.onFocus}}
          {{on "blur" this.onBlur}}
          {{on "paste" this.onPaste}}
          aria-label={{i18n "d_otp.screen_reader" count=this.slots}}
          {{didInsert this.focusInput}}
          ...attributes
        />
      </div>
    </div>
  </template>
}
