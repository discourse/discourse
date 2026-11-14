// Negative type assertions for DCarousel: every invocation below must fail to
// compile. They are quarantined here because a Glint error directive
// suppresses reporting elsewhere in its file, which would let a positive
// assertion pass against a broken declaration. Positives live in
// d-carousel-test.gts.
import DCarousel from "discourse/ui-kit/d-carousel";

declare const engine: unknown;

const Negatives = <template>
  <DCarousel
    {{! @glint-expect-error - looping is a boolean, not a string }}
    @loop="yes"
    as |carousel|
  >
    <carousel.Track>
      {{! @glint-expect-error - a slide needs the key its dot and the state refer to }}
      <carousel.Slide>one</carousel.Slide>
      <carousel.Slide
        {{! @glint-expect-error - the engine is curried by the carousel, never supplied }}
        @carousel={{engine}}
        @key="two"
      >two</carousel.Slide>
    </carousel.Track>
    <carousel.Controls>
      {{! @glint-expect-error - a step button needs its accessible name }}
      <carousel.Previous />
      <carousel.Dots>
        {{! @glint-expect-error - a dot needs its accessible name }}
        <carousel.Dot @key="two" />
      </carousel.Dots>
      {{! @glint-expect-error - the counter takes no arguments }}
      <carousel.Counter @label="x" />
      <carousel.Next
        {{! @glint-expect-error - each step button has a fixed direction }}
        @direction="previous"
        @label="Next"
      />
    </carousel.Controls>
  </DCarousel>
</template>;

export default Negatives;
