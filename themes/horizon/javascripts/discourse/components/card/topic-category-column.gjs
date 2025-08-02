import { categoryLinkHTML } from "discourse/helpers/category-link";

const TopicCategoryColumn = <template>
  {{categoryLinkHTML @topic.category}}
</template>;

export default TopicCategoryColumn;
