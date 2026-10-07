import CategoriesOnly from "discourse/components/categories-only";

const CategoriesWithFeaturedTopics = <template>
  <div ...attributes>
    <CategoriesOnly @categories={{@categories}} @showTopics="true" />
  </div>
</template>;

export default CategoriesWithFeaturedTopics;
