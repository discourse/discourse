import { concat } from "@ember/helper";
import DCarousel from "discourse/ui-kit/d-carousel";

const PHOTOS = Array.from({ length: 12 }, (_, index) => `Photo ${index + 1}`);

function plusOne(index) {
  return index + 1;
}

export default <template>
  <div class="styleguide-carousel">
    <DCarousel @label="Photos" as |carousel|>
      <carousel.Track>
        {{#each PHOTOS as |photo|}}
          <carousel.Slide @key={{photo}}>
            <div class="styleguide-carousel__slide">{{photo}}</div>
          </carousel.Slide>
        {{/each}}
      </carousel.Track>
      <carousel.Controls>
        <carousel.Previous @label="Previous photo" />
        <carousel.Dots>
          {{#each PHOTOS as |photo|}}
            <carousel.Dot @key={{photo}} @label={{concat "Go to " photo}} />
          {{/each}}
        </carousel.Dots>
        <carousel.Counter />
        <carousel.Next @label="Next photo" />
      </carousel.Controls>
      <p class="styleguide-carousel__status">
        Showing
        {{plusOne carousel.activeIndex}}
        of
        {{carousel.count}}
      </p>
    </DCarousel>
  </div>
</template>
