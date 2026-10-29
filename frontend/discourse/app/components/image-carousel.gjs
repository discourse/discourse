import Component from "@glimmer/component";
import { helper } from "@ember/component/helper";
import { concat } from "@ember/helper";
import { trustHTML } from "@ember/template";
import DCarousel from "discourse/ui-kit/d-carousel";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

const plusOne = helper(([val]) => val + 1);
const getAspectRatio = helper(([width, height]) => {
  const w = parseInt(width, 10) || 1;
  const h = parseInt(height, 10) || 1;
  return trustHTML(`aspect-ratio: ${w} / ${h}`);
});

/**
 * The carousel presentation of a cooked image grid. Each item is an image
 * element lifted out of the post and framed at its own aspect ratio.
 */
export default class ImageCarousel extends Component {
  get items() {
    return this.args.data.items || [];
  }

  <template>
    <DCarousel
      class={{dConcatClass
        "d-image-carousel"
        (if @data.mode (concat "d-image-carousel--" @data.mode))
      }}
      as |carousel|
    >
      <carousel.Track class="d-image-carousel__track">
        {{#each this.items as |item index|}}
          <carousel.Slide
            class="d-image-carousel__slide"
            data-index={{index}}
            style={{getAspectRatio item.width item.height}}
            @key={{index}}
          >
            {{item.element}}
          </carousel.Slide>
        {{/each}}
      </carousel.Track>

      <carousel.Controls class="d-image-carousel__controls">
        <carousel.Previous
          class="d-image-carousel__nav d-image-carousel__nav--prev"
          @label={{i18n "carousel.previous"}}
        />

        <carousel.Dots class="d-image-carousel__dots">
          {{#each this.items as |_item index|}}
            <carousel.Dot
              class="d-image-carousel__dot"
              @key={{index}}
              @label={{i18n "carousel.go_to_slide" index=(plusOne index)}}
            />
          {{/each}}
        </carousel.Dots>
        <carousel.Counter class="d-image-carousel__counter" />

        <carousel.Next
          class="d-image-carousel__nav d-image-carousel__nav--next"
          @label={{i18n "carousel.next"}}
        />
      </carousel.Controls>
    </DCarousel>
  </template>
}
