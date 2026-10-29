import { concat } from "@ember/helper";
import DCarousel from "discourse/ui-kit/d-carousel";

const PLACES = ["Mountains", "Harbour", "Forest", "Desert"];

export default <template>
  <div class="styleguide-carousel">
    <DCarousel @label="Places" as |carousel|>
      <carousel.Track>
        {{#each PLACES as |place|}}
          <carousel.Slide @key={{place}}>
            <div class="styleguide-carousel__slide">{{place}}</div>
          </carousel.Slide>
        {{/each}}
      </carousel.Track>
      <carousel.Controls>
        <carousel.Previous @label="Previous slide" />
        <carousel.Dots>
          {{#each PLACES as |place|}}
            <carousel.Dot @key={{place}} @label={{concat "Go to " place}} />
          {{/each}}
        </carousel.Dots>
        <carousel.Next @label="Next slide" />
      </carousel.Controls>
    </DCarousel>
  </div>
</template>
