import { categoryLinkHTML } from "discourse/ui-kit/helpers/d-category-link";

const TopicCategoryColumn = <template>
  {{categoryLinkHTML @topic.category}}
</template>;

export default TopicCategoryColumn;
