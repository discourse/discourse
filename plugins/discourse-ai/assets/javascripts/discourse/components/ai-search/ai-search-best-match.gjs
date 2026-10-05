import { or } from "discourse/truth-helpers";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const AiSearchBestMatch = <template>
  <span
    aria-label={{or @label (i18n "discourse_ai.ai_search.best_match")}}
    class="ai-search-best-match"
    role="img"
    title={{or @label (i18n "discourse_ai.ai_search.best_match")}}
    ...attributes
  >{{dIcon "star"}}</span>
</template>;

export default AiSearchBestMatch;
