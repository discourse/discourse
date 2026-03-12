import categoryLink from "discourse/ui-kit/helpers/d-category-link";

const Category = <template>
  {{categoryLink @result link=false allowUncategorized=true}}
</template>;

export default Category;
