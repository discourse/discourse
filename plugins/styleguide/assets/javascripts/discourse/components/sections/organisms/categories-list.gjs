import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import CategoriesOnlyExample from "../../examples/organisms/categories-only";
import categoriesOnlySource from "../../examples/organisms/categories-only?source=file";

export default <template>
  <StyleguideExample @code={{categoriesOnlySource}} @title="<CategoriesOnly>">
    <CategoriesOnlyExample />
  </StyleguideExample>
</template>
