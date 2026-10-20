import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import TrackedMediaQuery from "discourse/lib/tracked-media-query";
import DButton from "discourse/ui-kit/d-button";
import AiSearchReferencesModal from "../../components/modal/ai-search-references-modal.gjs";
import { combinedSearchActive } from "../../lib/ai-search-scope.js";

// matches the width below which core shows no timeline, and so no cited topics
const TIMELINE_MIN_WIDTH = 925;

/**
 * Opens a search conversation's cited topics where the timeline, which lists
 * them otherwise, does not fit.
 */
export default class AiSearchConversationReferencesButton extends Component {
  static shouldRender(args, { siteSettings, currentUser }) {
    return (
      Boolean(args.topic?.ai_search_conversation) &&
      combinedSearchActive(siteSettings, currentUser)
    );
  }

  @service modal;
  @service site;

  #wideQuery = new TrackedMediaQuery(`(min-width: ${TIMELINE_MIN_WIDTH}px)`);

  willDestroy() {
    super.willDestroy(...arguments);
    this.#wideQuery.teardown();
  }

  get timelineFits() {
    return !this.site.mobileView && this.#wideQuery.matches;
  }

  @action
  showReferences() {
    this.modal.show(AiSearchReferencesModal, {
      model: { topic: this.args.outletArgs.topic },
    });
  }

  <template>
    {{#unless this.timelineFits}}
      <DButton
        class="btn-default ai-search-references-button"
        @action={{this.showReferences}}
        @icon="link"
        @label="discourse_ai.ai_search.references_title"
      />
    {{/unless}}
  </template>
}
