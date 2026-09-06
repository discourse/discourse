import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import BreadCrumbsExample from "../../examples/molecules/bread-crumbs";
import breadCrumbsSource from "../../examples/molecules/bread-crumbs?source=file";

export default <template>
  <StyleguideExample @title="<BreadCrumbs>" @code={{breadCrumbsSource}}>
    <BreadCrumbsExample @categories={{@dummy.categories}} />
  </StyleguideExample>
</template>
