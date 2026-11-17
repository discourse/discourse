import dCategoryLink from "discourse/ui-kit/helpers/d-category-link";

const Category = <template>
  {{dCategoryLink @ctx.category allowUncategorized=true}}
</template>;

export default Category;
