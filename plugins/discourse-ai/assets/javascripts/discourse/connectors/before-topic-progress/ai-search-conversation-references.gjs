import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import AiSearchReferencesModal from "../../components/modal/ai-search-references-modal.gjs";
import { combinedSearchActive } from "../../lib/ai-search-scope.js";

// where the timeline cannot fit, its cited topics open from beside the progress bar
export default class AiSearchConversationReferencesButton extends Component {
  static shouldRender(args, { siteSettings, currentUser }) {
    return (
      Boolean(args.model?.ai_search_conversation) &&
      combinedSearchActive(siteSettings, currentUser)
    );
  }

  @service modal;

  @action
  showReferences() {
    this.modal.show(AiSearchReferencesModal, {
      model: { topic: this.args.outletArgs.model },
    });
  }

  <template>
    <DButton
      class="btn-default ai-search-references-button"
      @action={{this.showReferences}}
      @icon="link"
      @label="discourse_ai.ai_search.references_title"
    />
  </template>
}
