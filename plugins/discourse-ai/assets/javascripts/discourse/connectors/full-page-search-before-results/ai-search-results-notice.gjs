import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import { i18n } from "discourse-i18n";

const AI_RESULTS_TOGGLED = "full-page-search:ai-results-toggled";

export default class AiSearchResultsNotice extends Component {
  static shouldRender(args, { siteSettings }) {
    return siteSettings.ai_embeddings_semantic_search_enabled;
  }

  @service appEvents;

  @tracked showNotice = false;

  listenForAiResults = modifier(() => {
    const onToggled = ({ enabled, autoEnabled }) => {
      this.showNotice = enabled && autoEnabled;
    };
    const onNewSearch = () => {
      this.showNotice = false;
    };

    this.appEvents.on(AI_RESULTS_TOGGLED, onToggled);
    this.appEvents.on("full-page-search:trigger-search", onNewSearch);

    return () => {
      this.appEvents.off(AI_RESULTS_TOGGLED, onToggled);
      this.appEvents.off("full-page-search:trigger-search", onNewSearch);
    };
  });

  <template>
    <span {{this.listenForAiResults}}>
      {{#if this.showNotice}}
        <div class="ai-search-results-notice">
          {{i18n "discourse_ai.embeddings.ai_results_notice.no_results"}}
        </div>
      {{/if}}
    </span>
  </template>
}
