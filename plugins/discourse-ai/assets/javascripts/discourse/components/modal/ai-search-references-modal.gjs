import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";
import AiSearchReferencesPanel from "../ai-search/ai-search-references-panel.gjs";

const AiSearchReferencesModal = <template>
  <DModal
    class="ai-search-references-modal"
    @closeModal={{@closeModal}}
    @title={{i18n "discourse_ai.ai_search.references_title"}}
  >
    <:body>
      <AiSearchReferencesPanel
        class="--in-modal"
        @references={{@model.citedTopics.references}}
      />
    </:body>
  </DModal>
</template>;

export default AiSearchReferencesModal;
