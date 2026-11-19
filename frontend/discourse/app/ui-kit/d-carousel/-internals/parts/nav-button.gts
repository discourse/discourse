import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import type { DCarouselNavSignature } from "discourse/ui-kit/d-carousel/types";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";

/** A step button, curried into the `Previous` and `Next` parts. */
export default class NavButton extends Component<DCarouselNavSignature> {
  get isPrevious() {
    return this.args.direction === "previous";
  }

  get isDisabled() {
    return this.isPrevious
      ? !this.args.carousel.canGoPrevious
      : !this.args.carousel.canGoNext;
  }

  @action
  step() {
    if (this.isPrevious) {
      this.args.carousel.previous();
    } else {
      this.args.carousel.next();
    }
  }

  <template>
    {{! Splattributes come first so the name and disabled state below win. }}
    <button
      class={{dConcatClass
        "d-carousel__nav"
        (if this.isPrevious "--previous" "--next")
      }}
      ...attributes
      aria-label={{@label}}
      disabled={{this.isDisabled}}
      title={{@label}}
      type="button"
      {{on "click" this.step}}
    >
      {{dIcon (if this.isPrevious "chevron-left" "chevron-right")}}
    </button>
  </template>
}
