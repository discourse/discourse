import type { TOC } from "@ember/component/template-only";
import type { DCarouselControlsSignature } from "discourse/ui-kit/d-carousel/types";

/**
 * The navigation row. A single slide has nothing to page between, so the
 * row stays out of the DOM entirely rather than rendering inert controls.
 */
const Controls: TOC<DCarouselControlsSignature> = <template>
  {{#if @carousel.pageable}}
    <div class="d-carousel__controls" ...attributes>{{yield}}</div>
  {{/if}}
</template>;

export default Controls;
