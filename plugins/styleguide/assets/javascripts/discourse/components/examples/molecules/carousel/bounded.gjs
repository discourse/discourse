import { concat } from "@ember/helper";
import DCarousel from "discourse/ui-kit/d-carousel";

const STEPS = ["Welcome", "Choose a plan", "Confirm"];

export default <template>
  <div class="styleguide-carousel">
    <DCarousel @label="Setup steps" @loop={{false}} as |carousel|>
      <carousel.Track>
        {{#each STEPS as |step|}}
          <carousel.Slide @key={{step}}>
            <div class="styleguide-carousel__slide">{{step}}</div>
          </carousel.Slide>
        {{/each}}
      </carousel.Track>
      <carousel.Controls>
        <carousel.Previous @label="Previous step" />
        <carousel.Dots>
          {{#each STEPS as |step|}}
            <carousel.Dot @key={{step}} @label={{concat "Go to " step}} />
          {{/each}}
        </carousel.Dots>
        <carousel.Next @label="Next step" />
      </carousel.Controls>
    </DCarousel>
  </div>
</template>
