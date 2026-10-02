import Component from "@glimmer/component";
import { cancel, next } from "@ember/runloop";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import { isValidSearchTerm } from "discourse/lib/search";
import { eq } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";
import AiDiscoveriesSearchOptions from "../../components/ai-discoveries-search-options";
import AiSearchAnswer from "../../components/ai-search/ai-search-answer";
import AiSearchEntities from "../../components/ai-search/ai-search-entities";
import AiSearchDiscoveries from "../../components/ai-search-discoveries";
import {
  matchesPlaces,
  suggestionInProgress,
} from "../../lib/ai-search-intent";
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

  // A search can start from a pause rather than a key press, so the session
  // is given the menu's own way to show topics.
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
      dismissedKey: this.aiSearchSession.dismissedScope?.key,
    });
  }

  get term() {
    return this.args.outletArgs.searchTerm?.trim() ?? "";
  }

  get showCombined() {
    return (
      isValidSearchTerm(this.term, this.siteSettings) &&
      !suggestionInProgress(this.term) &&
      (this.showAnswer ||
        matchesPlaces(this.search.results) ||
        Boolean(this.aiSearchSession.dismissedScope))
    );
  }

  get showNoKeywordMatches() {
    return (
      this.aiSearchSession.surface === "menu" &&
      this.aiSearchSession.isActiveFor(this.term) &&
      this.aiSearchSession.noKeywordMatches &&
      !this.aiSearchSession.expanded
    );
  }

  get showAnswer() {
    return (
      this.aiSearchSession.isActiveFor(this.term) &&
      this.aiSearchSession.answering
    );
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
      <span
        hidden
        {{this.connectMenu}}
        {{this.followScope this.currentScope}}
        {{this.guardResults this.search.results}}
      ></span>
      {{#if this.showCombined}}
        <div class="ai-search-menu-answer">
          {{#if this.showAnswer}}
            <AiSearchAnswer
              @compact={{true}}
              @onNavigate={{@outletArgs.closeSearchMenu}}
            />
          {{/if}}
          {{#unless this.aiSearchSession.expanded}}
            <AiSearchEntities @onNavigate={{@outletArgs.closeSearchMenu}} />
          {{/unless}}
        </div>
      {{/if}}
      {{#if this.showNoKeywordMatches}}
        <div class="no-results">
          {{i18n "discourse_ai.ai_search.no_keyword_matches"}}
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
