import CategoriesOnly from "discourse/components/categories-only";
import CategoriesTopicList from "discourse/components/categories-topic-list";
import PluginOutlet from "discourse/components/plugin-outlet";

const CategoriesAndTopTopics = <template>
  <div class="categories-and-top" ...attributes>
    <div class="column categories">
      <CategoriesOnly @categories={{@categories}} />
    </div>

    <div class="column">
      <CategoriesTopicList
        class="top-topic-list"
        @filter="top"
        @topics={{@topics}}
      />
    </div>

    <PluginOutlet @connectorTagName="div" @name="extra-categories-column" />
  </div>
</template>;

export default CategoriesAndTopTopics;
