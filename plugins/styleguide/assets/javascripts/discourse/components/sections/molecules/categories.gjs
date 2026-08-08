import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import CategoryBadgeExample from "../../examples/molecules/category-badge";
import categoryBadgeSource from "../../examples/molecules/category-badge?source=file";

export default <template>
  <StyleguideExample @title="categoryBadge" @code={{categoryBadgeSource}}>
    <CategoryBadgeExample @categories={{@dummy.categories}} />
  </StyleguideExample>
</template>
