import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import type { DCarouselDotSignature } from "discourse/ui-kit/d-carousel/types";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

/** One dot: a jump to the slide registered under the same key. */
export default class Dot extends Component<DCarouselDotSignature> {
  get isActive() {
    return this.args.key === this.args.carousel.activeKey;
  }

  @action
  jump() {
    this.args.carousel.scrollToKey(this.args.key);
  }

  <template>
    {{! Splattributes come first so the name and current state below win. }}
    <button
      class={{dConcatClass "d-carousel__dot" (if this.isActive "--active")}}
      ...attributes
      aria-current={{if this.isActive "true"}}
      aria-label={{@label}}
      type="button"
      {{on "click" this.jump}}
    ></button>
  </template>
}
