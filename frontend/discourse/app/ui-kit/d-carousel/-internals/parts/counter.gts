import type { TOC } from "@ember/component/template-only";
import type { DCarouselCounterSignature } from "discourse/ui-kit/d-carousel/types";

function position(activeIndex: number) {
  return activeIndex + 1;
}

/**
 * A "position / total" readout. It is the counterpart of `Dots`: it renders
 * only once there are too many slides for dots, so the two can sit side by
 * side and exactly one shows.
 */
const Counter: TOC<DCarouselCounterSignature> = <template>
  {{#unless @carousel.fitsDots}}
    <span class="d-carousel__counter" ...attributes>{{position
        @carousel.activeIndex
      }}
      /
      {{@carousel.count}}</span>
  {{/unless}}
</template>;

export default Counter;
