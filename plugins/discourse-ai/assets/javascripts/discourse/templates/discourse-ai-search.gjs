import { array, concat } from "@ember/helper";
import AiSearchPage from "../components/ai-search/ai-search-page";

export default <template>
  {{! keyed so moving to another conversation or query, including through
      history, starts from a clean component }}
  {{#each (array (concat @controller.topic "|" @controller.q)) key="@identity"}}
    <AiSearchPage
      @onQueryChange={{@controller.updateQuery}}
      @query={{@controller.q}}
      @scope={{@controller.scope}}
      @topicId={{@controller.topic}}
    />
  {{/each}}
</template>
