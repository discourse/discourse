import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import { i18n } from "discourse-i18n";

export default class AiQuickSearchNotice extends Component {
  static shouldRender(args, { siteSettings }) {
    return (
      siteSettings.ai_embeddings_semantic_quick_search_enabled &&
      args.resultType?.type === "topic"
    );
  }

  @service appEvents;

  @tracked searching = false;

  listenForAiSearch = modifier(() => {
    const onStateChanged = ({ searching }) => {
      this.searching = searching;
    };

    this.appEvents.on("ai-quick-search:state-changed", onStateChanged);

    return () => {
      this.appEvents.off("ai-quick-search:state-changed", onStateChanged);
    };
  });

  get results() {
    return this.args.outletArgs?.resultType?.results || [];
  }

  get hasAiResults() {
    return this.results.some((result) => result.aiGenerated);
  }

  get regularResultCount() {
    return this.results.filter((result) => !result.aiGenerated).length;
  }

  get noticeText() {
    if (!this.hasAiResults) {
      return null;
    }

    if (this.regularResultCount === 0) {
      return i18n("discourse_ai.embeddings.ai_results_notice.no_results");
    }
    return i18n("discourse_ai.embeddings.ai_results_notice.few_results", {
      count: this.regularResultCount,
    });
  }

  <template>
    <span {{this.listenForAiSearch}}>
      {{#if this.searching}}
        <div class="ai-quick-search-notice">
          <div class="spinner small"></div>
        </div>
      {{else if this.noticeText}}
        <div class="ai-quick-search-notice">
          {{this.noticeText}}
        </div>
      {{/if}}
    </span>
  </template>
}
