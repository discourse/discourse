import CategoriesOnly from "discourse/components/categories-only";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

const CategoriesList = <template>
  <StyleguideExample @title="<CategoriesOnly>">
    <CategoriesOnly @categories={{@dummy.categories}} />
  </StyleguideExample>
</template>;

export default CategoriesList;
