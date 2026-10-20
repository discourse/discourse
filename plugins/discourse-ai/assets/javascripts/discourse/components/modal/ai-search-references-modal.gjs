import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";
import AiSearchConversationReferences from "../ai-search/ai-search-conversation-references.gjs";

const AiSearchReferencesModal = <template>
  <DModal
    class="ai-search-references-modal"
    @closeModal={{@closeModal}}
    @title={{i18n "discourse_ai.ai_search.references_title"}}
  >
    <:body>
      <AiSearchConversationReferences
        class="--in-modal"
        @topic={{@model.topic}}
      />
    </:body>
  </DModal>
</template>;

export default AiSearchReferencesModal;
