import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { isBlank } from "@ember/utils";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import autoFocus from "discourse/modifiers/auto-focus";
import preventScrollOnFocus from "discourse/modifiers/prevent-scroll-on-focus";
import { i18n } from "discourse-i18n";
import Slot from "./slot";

const DEFAULT_SLOTS = 6;

export default class DOTP extends Component {
  @tracked isFocused = false;
  @tracked isAllSelected = false;

  otp = new TrackedArray(Array(this.slots).fill(""));

  get slots() {
    return this.args.slots ?? DEFAULT_SLOTS;
  }

  get isFilled() {
    return this.otp.every((char) => !isBlank(char));
  }

  get value() {
    return this.otp.join("");
  }

  @action
  onInput(event) {
    const chars = event.target.value.split("");
    const wasFilled = this.isFilled;

    if (wasFilled && chars.length >= this.otp.length) {
      return;
    }

    for (let i = 0; i < this.otp.length; i++) {
      this.otp[i] = chars[i] || "";
    }

    const joinedOtp = this.otp.join("");

    this.args.onChange?.(joinedOtp);

    // Check if just became filled and call callback
    if (!wasFilled && this.isFilled) {
      this.args.onFill?.(joinedOtp);
    }

    this.isAllSelected = false;
  }

  @action
  onSelect(event) {
    const input = event.target;
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
  onKeyDown(event) {
    // Disable arrow keys as you can only fill last unfilled or backspace
    if (
      ["ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown"].includes(event.key)
    ) {
      event.preventDefault();
    }
  }

  @action
  onPaste(event) {
    const input = event.target;
    event.preventDefault(); // Prevent the call to input as we manually call it later

    const clipboardData = event.clipboardData || window.clipboardData;
    if (!clipboardData) {
      return;
    }

    const pastedData = clipboardData.getData("text");
    input.value = pastedData.replace(/[^0-9]/g, "");
    this.onInput({ target: input });
  }

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
        {{/each}}
      </div>

      <div class="d-otp-input-wrapper">
        <input
          {{preventScrollOnFocus}}
          inputmode="numeric"
          autocomplete="one-time-code"
          data-slot="input-otp"
          class="d-otp-input"
          maxlength={{this.slots}}
          {{on "input" this.onInput}}
          {{on "select" this.onSelect}}
          {{on "keydown" this.onKeyDown}}
          {{on "focus" this.onFocus}}
          {{on "blur" this.onBlur}}
          {{on "paste" this.onPaste}}
          {{(if @autoFocus (modifier autoFocus))}}
          aria-label={{i18n "d_otp.screen_reader" count=this.slots}}
          ...attributes
        />
      </div>
    </div>
  </template>
}
