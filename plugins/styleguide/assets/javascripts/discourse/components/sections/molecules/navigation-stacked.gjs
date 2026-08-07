import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import NavStackedExample from "../../examples/molecules/nav-stacked";
import navStackedSource from "../../examples/molecules/nav-stacked?source=file";
import UserNavStackedExample from "../../examples/molecules/user-nav-stacked";
import userNavStackedSource from "../../examples/molecules/user-nav-stacked?source=file";

export default <template>
  <StyleguideExample
    @title=".nav-stacked"
    class="half-size"
    @code={{navStackedSource}}
  >
    <NavStackedExample @navItems={{@dummy.navItems}} />
  </StyleguideExample>

  <StyleguideExample
    @title=".user-navigation .nav-stacked"
    class="half-size"
    @code={{userNavStackedSource}}
  >
    <UserNavStackedExample @navItems={{@dummy.navItems}} />
  </StyleguideExample>
</template>
