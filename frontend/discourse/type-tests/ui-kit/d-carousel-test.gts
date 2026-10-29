// Positive template invocations for DCarousel. Keep this file free of Glint
// directives: a single `@glint-expect-error` anywhere makes Glint stop
// reporting every other error in the file, so a broken declaration would pass
// unnoticed. Negatives live in d-carousel-errors-test.gts.
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import DCarousel from "discourse/ui-kit/d-carousel";

declare const loop: boolean;
declare const label: string;
declare const numericKey: number;

const Positives = <template>
  {{! Every part, each taking attributes, with string and numeric keys }}
  <DCarousel class="gallery" @label={{label}} @loop={{loop}} as |carousel|>
    <carousel.Track class="gallery__track" data-test-track="1">
      <carousel.Slide class="gallery__slide" @key="first">one</carousel.Slide>
      <carousel.Slide @key={{numericKey}}>two</carousel.Slide>
    </carousel.Track>
    <carousel.Controls class="gallery__controls">
      <carousel.Previous class="gallery__nav" @label="Previous" />
      <carousel.Dots class="gallery__dots">
        <carousel.Dot class="gallery__dot" @key="first" @label="Go to one" />
        <carousel.Dot @key={{numericKey}} @label="Go to two" />
      </carousel.Dots>
      <carousel.Counter class="gallery__counter" />
      <carousel.Next @label="Next" />
    </carousel.Controls>

    {{! The live state and the jump are yielded for custom indicators }}
    <p>{{carousel.activeKey}} {{carousel.activeIndex}} {{carousel.count}}</p>
    <button type="button" {{on "click" (fn carousel.scrollToKey "first")}}>
      Back to the first
    </button>
  </DCarousel>

  {{! Every argument is optional }}
  <DCarousel as |carousel|>
    <carousel.Track>
      <carousel.Slide @key="only">one</carousel.Slide>
    </carousel.Track>
  </DCarousel>
</template>;

export default Positives;
