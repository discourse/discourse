import type { TOC } from "@ember/component/template-only";
import type { DCarouselDotsSignature } from "discourse/ui-kit/d-carousel/types";

/**
 * The row of dots. Past a handful of slides a dot per slide stops being a
 * usable control, so the row then stays out of the DOM and a `Counter`
 * placed beside it takes over.
 */
const Dots: TOC<DCarouselDotsSignature> = <template>
  {{#if @carousel.fitsDots}}
    <div class="d-carousel__dots" ...attributes>{{yield}}</div>
  {{/if}}
</template>;

export default Dots;
