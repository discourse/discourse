import dCategoryLink from "discourse/ui-kit/helpers/d-category-link";

const Category = <template>
  {{dCategoryLink @result link=false allowUncategorized=true}}
</template>;

export default Category;
