import Component from "@glimmer/component";
import { cancel, next } from "@ember/runloop";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import { eq } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import AiDiscoveriesSearchOptions from "../../components/ai-discoveries-search-options";
import AiSearchAnswer from "../../components/ai-search/ai-search-answer";
import AiSearchDiscoveries from "../../components/ai-search-discoveries";
import { contextScope } from "../../lib/ai-search-scope";

export default class AiDiscobotDiscoveries extends Component {
  static shouldRender(args, { siteSettings, currentUser }) {
    return (
      ["header", "welcome-banner"].includes(args?.location) &&
      siteSettings.ai_ask_ai_enabled &&
      siteSettings.ai_ask_ai_agent &&
      currentUser?.can_use_ask_ai
    );
  }

  @service aiSearchSession;
  @service discobotDiscoveries;
  @service search;
  @service siteSettings;

  // deferred because a scope change re-runs the search, which updates state
  // this render has already read
  followScope = modifier((element, [scope]) => {
    const timer = next(() => this.aiSearchSession.updateContextScope(scope));
    return () => cancel(timer);
  });

  get combinedSearch() {
    return this.siteSettings.ai_ask_ai_combined_search_prototype;
  }

  get currentScope() {
    return contextScope(this.search, {
      inPMInboxContext: this.args.outletArgs.inPMInboxContext,
      dismissedKey: this.aiSearchSession.dismissedScope?.key,
    });
  }

  get showCombinedAnswer() {
    return this.aiSearchSession.isActiveFor(this.args.outletArgs.searchTerm);
  }

  get shouldShow() {
    return (
      this.args.outletArgs.searchTerm &&
      this.discobotDiscoveries.lastQuery ===
        this.args.outletArgs.searchTerm.trim()
    );
  }

  get isGenerating() {
    return (
      this.discobotDiscoveries.loadingDiscoveries ||
      this.discobotDiscoveries.isStreaming
    );
  }

  <template>
    {{#if this.combinedSearch}}
      {{! keeps the session in the menu's scope, so a chip taken off re-runs
          the search on screen }}
      <span hidden {{this.followScope this.currentScope}}></span>
      {{#if this.showCombinedAnswer}}
        <div class="ai-search-menu-answer">
          <AiSearchAnswer
            @compact={{true}}
            @onNavigate={{@outletArgs.closeSearchMenu}}
          />
        </div>
      {{/if}}
    {{else}}
      {{! rendered from here rather than its own connector so the options always
        lead the answer, whatever order connectors resolve in }}
      <AiDiscoveriesSearchOptions
        @clearPMInboxContext={{@outletArgs.clearPMInboxContext}}
        @clearTopicContext={{@outletArgs.clearTopicContext}}
        @inPMInboxContext={{@outletArgs.inPMInboxContext}}
        @openAdvancedSearch={{@outletArgs.openAdvancedSearch}}
        @searchTermChanged={{@outletArgs.searchTermChanged}}
        @searchTopics={{@outletArgs.searchTopics}}
        @triggerSearch={{@outletArgs.triggerSearch}}
        @updateTypeFilter={{@outletArgs.updateTypeFilter}}
      />

      {{#if this.shouldShow}}
        <div
          class={{dConcatClass
            "ai-discobot-discoveries"
            (if this.isGenerating "is-generating")
            (if this.discobotDiscoveries.sources.length "has-sources")
            (if (eq this.discobotDiscoveries.answerable false) "has-no-answer")
          }}
        >
          <AiSearchDiscoveries
            @closeSearchMenu={{@outletArgs.closeSearchMenu}}
            @searchTerm={{@outletArgs.searchTerm}}
            @showHeading={{true}}
            @showSources={{true}}
            @triggerOnInsert={{false}}
          />
        </div>
      {{/if}}
    {{/if}}
  </template>
}
