import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import NavigationExample from "../../examples/organisms/navigation";
import navigationSource from "../../examples/organisms/navigation?source=file";

export default <template>
  <StyleguideExample @title="navigation" @code={{navigationSource}}>
    <NavigationExample
      @categories={{@dummy.categories}}
      @navItems={{@dummy.navItems}}
    />
  </StyleguideExample>
</template>
