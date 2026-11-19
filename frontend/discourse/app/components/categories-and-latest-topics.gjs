import CategoriesOnly from "discourse/components/categories-only";
import CategoriesTopicList from "discourse/components/categories-topic-list";
import PluginOutlet from "discourse/components/plugin-outlet";

const CategoriesAndLatestTopics = <template>
  <div class="categories-and-latest" ...attributes>
    <div class="column categories">
      <CategoriesOnly @categories={{@categories}} />
    </div>

    <div class="column">
      <CategoriesTopicList
        class="latest-topic-list"
        @filter="latest"
        @topics={{@topics}}
      />
    </div>

    <PluginOutlet @connectorTagName="div" @name="extra-categories-column" />
  </div>
</template>;

export default CategoriesAndLatestTopics;
