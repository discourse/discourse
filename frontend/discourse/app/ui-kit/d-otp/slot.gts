import Component from "@glimmer/component";
import { isBlank } from "@ember/utils";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

const PLACEHOLDER_CHAR = "-";

interface SlotSignature {
  Args: {
    /** The character in the slot. */
    char?: string;

    /** The position of the slot. */
    index: number;

    /** Whether the slot holds the input cursor. */
    isFocused?: boolean;
  };
}

export default class Slot extends Component<SlotSignature> {
  get showCursor() {
    return this.args.isFocused && isBlank(this.args.char);
  }

  get displayChar() {
    if (!isBlank(this.args.char)) {
      return this.args.char;
    }

    if (this.showCursor) {
      return "";
    }

    return PLACEHOLDER_CHAR;
  }

  get isPlaceholder() {
    return this.displayChar === PLACEHOLDER_CHAR;
  }

  <template>
    <div
      class={{dConcatClass
        "d-otp-slot"
        (if @isFocused "--is-focused")
        (if this.showCursor "--show-cursor")
        (if this.isPlaceholder "--placeholder")
      }}
      data-index={{@index}}
    >
      <span aria-hidden="true">
        &#8203;
      </span>
      {{this.displayChar}}
    </div>
  </template>
}
