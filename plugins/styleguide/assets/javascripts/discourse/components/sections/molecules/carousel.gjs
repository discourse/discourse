import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import CarouselBasicExample from "../../examples/molecules/carousel/basic";
import carouselBasicSource from "../../examples/molecules/carousel/basic?source=file";
import CarouselBoundedExample from "../../examples/molecules/carousel/bounded";
import carouselBoundedSource from "../../examples/molecules/carousel/bounded?source=file";
import CarouselCounterExample from "../../examples/molecules/carousel/counter";
import carouselCounterSource from "../../examples/molecules/carousel/counter?source=file";

export default <template>
  <StyleguideExample
    @code={{carouselBasicSource}}
    @description="The carousel yields its parts and the consumer composes them: a Track holding Slides, and Controls holding the step buttons and a Dot per slide. Each slide is identified by a key, and the widget derives the active slide, the paging, and the ARIA state from the parts it finds. Stepping past either end wraps around by default."
    @title="<DCarousel> — slides, dots, and wrap-around"
  >
    <:tryThis>
      Click the arrows or a dot, or swipe the track. Focus the track and use the
      arrow keys: paging follows the reading direction, so left and right swap
      on a right-to-left page.
    </:tryThis>
    <:default>
      <CarouselBasicExample />
    </:default>
  </StyleguideExample>

  <StyleguideExample
    @code={{carouselBoundedSource}}
    @description="With looping off, the step button that has nowhere to go is disabled rather than wrapping. A guided sequence reads better this way than a loop."
    @title="<DCarousel> — bounded stepping"
  >
    <:tryThis>
      The previous button starts disabled. Step to the last slide and the next
      button is disabled in turn.
    </:tryThis>
    <:default>
      <CarouselBoundedExample />
    </:default>
  </StyleguideExample>

  <StyleguideExample
    @code={{carouselCounterSource}}
    @description="Past ten slides a dot per slide stops being a usable control, so the Dots part renders nothing and the Counter beside it takes over. Place both and exactly one shows. The live state is yielded too, for an indicator of your own."
    @title="<DCarousel> — a counter for many slides"
  >
    <:tryThis>
      Step through the twelve slides and watch the counter and the status line
      update together.
    </:tryThis>
    <:default>
      <CarouselCounterExample />
    </:default>
  </StyleguideExample>
</template>
