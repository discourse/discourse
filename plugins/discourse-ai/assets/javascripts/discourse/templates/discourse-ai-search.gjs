import { array } from "@ember/helper";
import AiSearchPage from "../components/ai-search/ai-search-page";

export default <template>
  {{! keyed so moving to another conversation starts from a clean component }}
  {{#each (array @controller.topic) key="@identity" as |topic|}}
    <AiSearchPage
      @onQueryChange={{@controller.updateQuery}}
      @query={{@controller.q}}
      @scope={{@controller.scope}}
      @topicId={{topic}}
    />
  {{/each}}
</template>
