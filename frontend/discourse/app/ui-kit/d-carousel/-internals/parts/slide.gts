import type { TOC } from "@ember/component/template-only";
import { eq } from "discourse/truth-helpers";
import type { DCarouselSlideSignature } from "discourse/ui-kit/d-carousel/types";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

/** One slide in the track, marked active while it is the one in view. */
const Slide: TOC<DCarouselSlideSignature> = <template>
  <div
    class={{dConcatClass
      "d-carousel__slide"
      (if (eq @key @carousel.activeKey) "--active")
    }}
    ...attributes
    {{@carousel.registerSlide @key}}
  >
    {{yield}}
  </div>
</template>;

export default Slide;
