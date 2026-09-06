import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import GroupNavPillsExample from "../../examples/molecules/group-nav-pills";
import groupNavPillsSource from "../../examples/molecules/group-nav-pills?source=file";
import NavigationBarExample from "../../examples/molecules/navigation-bar";
import navigationBarSource from "../../examples/molecules/navigation-bar?source=file";
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
</template>
