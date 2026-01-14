import categoryLink from "discourse/helpers/category-link";

const Category = <template>
  {{categoryLink @result link=false allowUncategorized=true}}
</template>;

export default Category;
