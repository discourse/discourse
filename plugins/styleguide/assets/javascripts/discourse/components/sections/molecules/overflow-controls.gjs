import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import OverflowControlsHorizontalExample from "../../examples/molecules/overflow-controls/horizontal";
import overflowControlsHorizontalSource from "../../examples/molecules/overflow-controls/horizontal?source=file";
import OverflowControlsOwnedExample from "../../examples/molecules/overflow-controls/owned";
import overflowControlsOwnedSource from "../../examples/molecules/overflow-controls/owned?source=file";
import OverflowControlsRevealExample from "../../examples/molecules/overflow-controls/reveal";
import overflowControlsRevealSource from "../../examples/molecules/overflow-controls/reveal?source=file";
import OverflowControlsVerticalExample from "../../examples/molecules/overflow-controls/vertical";
import overflowControlsVerticalSource from "../../examples/molecules/overflow-controls/vertical?source=file";

export default <template>
  <StyleguideExample
    @title="<DOverflowControls> — a horizontal strip"
    @code={{overflowControlsHorizontalSource}}
    @description="Content wider than its container scrolls sideways with the scrollbar hidden. The edge that has more content fades out, and a chevron sits on it. A click scrolls one viewport; holding the chevron keeps scrolling until you release."
  >
    <:tryThis>
      Click the right chevron once, then press and hold it. Swipe or
      Shift-scroll the strip and watch the chevrons swap sides as you reach each
      end.
    </:tryThis>
    <:default>
      <OverflowControlsHorizontalExample />
    </:default>
  </StyleguideExample>

  <StyleguideExample
    @title="<DOverflowControls> — a vertical column"
    @code={{overflowControlsVerticalSource}}
    @description="The same controls follow whichever axis the content's overflow lets it scroll on, so a bounded column gets up and down chevrons with no extra arguments."
  >
    <:tryThis>
      Scroll the column and watch the top chevron appear once the first row
      leaves view.
    </:tryThis>
    <:default>
      <OverflowControlsVerticalExample />
    </:default>
  </StyleguideExample>

  <StyleguideExample
    @title="<DOverflowControls> — a consumer-owned scroller"
    @code={{overflowControlsOwnedSource}}
    @description="With the owned-scroller argument the consumer renders the scrolling element itself and applies the yielded modifier to it. That keeps the element's own role and styling, which is how the navigation bar and the tab strip use it."
  >
    <:tryThis>
      Inspect the list: it is a plain list element with its own class and
      accessible name, and the chevrons are its siblings rather than its
      children.
    </:tryThis>
    <:default>
      <OverflowControlsOwnedExample />
    </:default>
  </StyleguideExample>

  <StyleguideExample
    @title="<DOverflowControls> — revealing an item"
    @code={{overflowControlsRevealSource}}
    @description="The yielded reveal function scrolls the strip, and only the strip, until an element is inside it. Nearest moves the least distance that clears the fade band; center puts the element in the middle. The page never moves."
  >
    <:tryThis>
      Use the buttons above the strip. Nearest brings item 9 to the trailing
      edge; centered puts item 4 in the middle of the strip.
    </:tryThis>
    <:default>
      <OverflowControlsRevealExample />
    </:default>
  </StyleguideExample>
</template>
