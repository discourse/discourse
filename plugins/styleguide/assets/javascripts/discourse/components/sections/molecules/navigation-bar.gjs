import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import GroupNavPillsExample from "../../examples/molecules/group-nav-pills";
import groupNavPillsSource from "../../examples/molecules/group-nav-pills?source=file";
import NavigationBarExample from "../../examples/molecules/navigation-bar";
import navigationBarSource from "../../examples/molecules/navigation-bar?source=file";
import OverflowingNavExample from "../../examples/molecules/overflowing-nav";
import overflowingNavSource from "../../examples/molecules/overflowing-nav?source=file";
import UserNavPillsExample from "../../examples/molecules/user-nav-pills";
import userNavPillsSource from "../../examples/molecules/user-nav-pills?source=file";

export default <template>
  <StyleguideExample @title="<NavigationBar>" @code={{navigationBarSource}}>
    <NavigationBarExample @navItems={{@dummy.navItems}} />
  </StyleguideExample>

  <StyleguideExample
    @title=".user-main .nav-pills"
    @code={{userNavPillsSource}}
  >
    <UserNavPillsExample @navItems={{@dummy.navItems}} />
  </StyleguideExample>

  <StyleguideExample
    @title="group page <NavigationBar>"
    @code={{groupNavPillsSource}}
  >
    <GroupNavPillsExample @navItems={{@dummy.navItems}} />
  </StyleguideExample>

  <StyleguideExample
    @title="<DHorizontalOverflowNav> — more items than fit"
    @code={{overflowingNavSource}}
    @description="A navigation bar that outgrows its width scrolls sideways instead of wrapping. The edge with more items fades out under a chevron, a click scrolls one viewport, holding the chevron keeps scrolling, and the active item is brought into view when the bar mounts."
  >
    <:tryThis>
      The active item started off screen and was centered on mount. Click or
      hold a chevron, or swipe the bar, and watch the chevrons swap sides at
      each end.
    </:tryThis>
    <:default>
      <OverflowingNavExample />
    </:default>
  </StyleguideExample>
</template>
