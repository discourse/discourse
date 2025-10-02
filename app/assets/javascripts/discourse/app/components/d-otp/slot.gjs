import Component from "@glimmer/component";
import { isBlank } from "@ember/utils";
import { modifier as modifierFn } from "ember-modifier";
import concatClass from "discourse/helpers/concat-class";

const animateOnFocus = modifierFn((element, [isFocused]) => {
  if (isFocused) {
    element.animate(
      [
        { transform: "scale(1)" },
        { transform: "scale(1.1)" },
        { transform: "scale(1)" },
      ],
      {
        duration: 400,
        easing: "ease-out",
        fill: "none",
      }
    );
  }
});

const PLACEHOLDER_CHAR = "-";

export default class Slot extends Component {
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
      class={{concatClass
        "d-otp-slot"
        (if @isFocused "--is-focused")
        (if this.showCursor "--show-cursor")
        (if this.isPlaceholder "--placeholder")
      }}
      data-index={{@index}}
      {{animateOnFocus @isFocused}}
    >
      {{this.displayChar}}
    </div>
  </template>
}
