import Component from "@glimmer/component";
import { cancel, next } from "@ember/runloop";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import { eq } from "discourse/truth-helpers";
import DSkeleton from "discourse/ui-kit/d-skeleton";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";
import AiDiscoveriesSearchOptions from "../../components/ai-discoveries-search-options";
import AiSearchAnswer from "../../components/ai-search/ai-search-answer";
import AiSearchTabs from "../../components/ai-search/ai-search-tabs";
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

  // A search can start from somewhere other than a key press, such as a recent
  // search picked from the menu, so the session is given the menu's own way to
  // show topics.
  connectMenu = modifier(() => {
    this.aiSearchSession.showTopicsInMenu = () =>
      this.args.outletArgs.updateTypeFilter(null);
    return () => (this.aiSearchSession.showTopicsInMenu = null);
  });

  // These are deferred because what they set off updates state this render
  // has already read.
  guardResults = modifier((element, [results]) => {
    if (results) {
      const timer = next(() => this.aiSearchSession.guardMenuResults());
      return () => cancel(timer);
    }
  });

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
    });
  }

  get term() {
    return this.args.outletArgs.searchTerm?.trim() ?? "";
  }

  // tabs and results belong to a search that has run, not to the typing
  // before it, which shows the menu's own suggestions
  get searched() {
    return (
      this.aiSearchSession.surface === "menu" &&
      this.aiSearchSession.isActiveFor(this.term)
    );
  }

  get tab() {
    return this.aiSearchSession.selectedTab;
  }

  get showNoKeywordMatches() {
    return this.aiSearchSession.noKeywordMatches;
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
      <span
        hidden
        {{this.connectMenu}}
        {{this.followScope this.currentScope}}
        {{this.guardResults this.search.results}}
      ></span>
      {{#if this.searched}}
        <AiSearchTabs />

        {{#if (eq this.tab "ask")}}
          <div class="ai-search-menu-answer">
            <AiSearchAnswer
              @compact={{true}}
              @onNavigate={{@outletArgs.closeSearchMenu}}
            />
          </div>
        {{else if (eq this.tab null)}}
          {{! until the keyword searches are in and a tab is chosen }}
          <div class="ai-search-menu-loading">
            <DSkeleton @count={{3}} @lastLineWidth="70%" />
          </div>
        {{/if}}

        {{#if this.showNoKeywordMatches}}
          <div class="no-results">
            {{i18n "discourse_ai.ai_search.no_keyword_matches"}}
          </div>
        {{/if}}
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
