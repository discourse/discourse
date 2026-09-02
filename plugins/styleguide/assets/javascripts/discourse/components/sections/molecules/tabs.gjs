import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import TabsBasicExample from "../../examples/molecules/tabs/basic";
import tabsBasicSource from "../../examples/molecules/tabs/basic?source=file";
import TabsHeaderExample from "../../examples/molecules/tabs/header";
import tabsHeaderSource from "../../examples/molecules/tabs/header?source=file";
import TabsOverflowExample from "../../examples/molecules/tabs/overflow";
import tabsOverflowSource from "../../examples/molecules/tabs/overflow?source=file";
import TabsVerticalExample from "../../examples/molecules/tabs/vertical";
import tabsVerticalSource from "../../examples/molecules/tabs/vertical?source=file";

export default <template>
  <StyleguideExample
    @title="<DTabs> — controlled selection"
    @code={{tabsBasicSource}}
    @description="Each tab declares its strip button and its panel content together, and the widget derives the tablist, the roving tab stop, and the ARIA pairing from that. Selection is controlled: the widget reports the tab the user picks and nothing moves until the owner feeds the id back."
  >
    <:tryThis>
      Move through the strip with the arrow keys, which wrap at either end. The
      disabled tab still takes focus, so it stays discoverable, but Enter and
      Space leave it inert. Use the button above the strip to change the
      selection from outside and watch the tab stop follow it.
    </:tryThis>
    <:default>
      <TabsBasicExample />
    </:default>
  </StyleguideExample>

  <StyleguideExample
    @title="<DTabs> — a header block with extra chrome"
    @code={{tabsHeaderSource}}
    @description="A header block replaces the default strip row. The consumer lays out its own row and places the yielded Tablist part wherever it wants; the tab buttons still render inside it and the keyboard surface travels with it."
  >
    <:tryThis>
      Press Tab from the strip: focus lands on the refresh button, which sits on
      the same row but is not a tab. Press the button and read the count in the
      summary panel.
    </:tryThis>
    <:default>
      <TabsHeaderExample />
    </:default>
  </StyleguideExample>

  <StyleguideExample
    @title="<DTabs> — an overflowing strip"
    @code={{tabsOverflowSource}}
    @description="A strip wider than its container scrolls sideways rather than wrapping, with the scrollbar hidden. The edge with more tabs fades out under a chevron: a click scrolls one viewport and holding it keeps scrolling. Whenever the selection changes, the widget scrolls the strip just far enough to bring the selected tab fully into view, and it never scrolls the page to do so."
  >
    <:tryThis>
      Click or hold a chevron, swipe or Shift-scroll the strip, or walk to the
      hidden tabs with the arrow keys. Then use the buttons above to jump the
      selection between the first and last tab and watch the strip follow.
    </:tryThis>
    <:default>
      <TabsOverflowExample />
    </:default>
  </StyleguideExample>

  <StyleguideExample
    @title="<DTabs> — vertical orientation"
    @code={{tabsVerticalSource}}
    @description="The orientation argument flips the arrow-key axis and announces it on the tablist. Laying the strip out beside the panel is the consumer's job, since the widget only owns the interaction."
  >
    <:tryThis>
      Up and Down move between tabs. Left and Right do nothing. Home and End
      still jump to the first and last tab.
    </:tryThis>
    <:default>
      <TabsVerticalExample />
    </:default>
  </StyleguideExample>
</template>
