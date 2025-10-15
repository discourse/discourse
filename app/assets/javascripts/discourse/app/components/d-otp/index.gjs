import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { isBlank } from "@ember/utils";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import Slot from "./slot";

export default class DOTP extends Component {
  @tracked isFocused = false;
  @tracked isAllSelected = false;

  constructor() {
    super(...arguments);

    this.otp = new TrackedArray(Array(this.slots).fill(""));
  }

  get slots() {
    return this.args.slots ?? 6;
  }

  isFilledNow() {
    return this.otp.every((char) => !isBlank(char));
  }

  @action
  onInput(event) {
    const chars = event.target.value.split("");
    let wasFilled = this.isFilledNow();

    // Check if currently filled and prevent overwriting last character
    if (wasFilled && chars.length >= this.otp.length) {
      event.target.value = this.otp.join("");
      return;
    }

    for (let i = 0; i < this.otp.length; i++) {
      this.otp[i] = chars[i] || "";
    }

    // Check if just became filled and call callback
    if (!wasFilled && this.isFilledNow()) {
      // next to ensure we call the callback after the last character is rendered
      next(() => {
        this.args.onFilled?.(this.otp.join(""));
      });
    }

    // Reset selection state on input change
    this.isAllSelected = false;
  }

  @action
  onSelect(event) {
    const input = event.target;
    const hasSelection = input.selectionStart !== input.selectionEnd;
    const isEntireTextSelected =
      hasSelection &&
      input.selectionStart === 0 &&
      input.selectionEnd === input.value.length;

    this.isAllSelected = isEntireTextSelected;
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
    const cleanedData = pastedData.replace(/[^0-9]/g, "");

    // Set the cleaned value and trigger input event
    input.value = cleanedData;
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
        />
      </div>
    </div>
  </template>
}
