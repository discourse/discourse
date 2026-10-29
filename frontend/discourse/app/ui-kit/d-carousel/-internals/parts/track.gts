import type { TOC } from "@ember/component/template-only";
import { on } from "@ember/modifier";
import type { DCarouselTrackSignature } from "discourse/ui-kit/d-carousel/types";

/**
 * The scroll-snapping viewport the slides render into. It is also the
 * keyboard surface: while it has focus, the arrow keys page the carousel.
 */
const Track: TOC<DCarouselTrackSignature> = <template>
  {{! Splattributes come first so the group semantics and tab stop below win. }}
  <div
    class="d-carousel__track"
    ...attributes
    aria-label={{@carousel.label}}
    role="group"
    tabindex="0"
    {{on "keydown" @carousel.onTrackKeyDown}}
    {{@carousel.registerTrack}}
  >
    {{yield}}
  </div>
</template>;

export default Track;
