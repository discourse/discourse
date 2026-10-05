import Component from "@glimmer/component";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { service } from "@ember/service";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dRovingFocus from "discourse/ui-kit/modifiers/d-roving-focus";
import { i18n } from "discourse-i18n";
import AiSearchBestMatch from "./ai-search-best-match";

/**
 * The kinds of result a combined search fetched, as pills that switch between
 * them. Each keyword tab says how much it found, so an empty one is plain
 * before it is opened.
 */
export default class AiSearchTabs extends Component {
  @service aiSearchSession;
  @service search;

  get session() {
    return this.aiSearchSession;
  }

  get tabs() {
    const tabs = [
      this.#keywordTab(
        "topics",
        i18n("discourse_ai.ai_search.tabs.topics"),
        this.session.topicsResults
      ),
    ];

    const scope = this.session.scope;
    if (scope) {
      tabs.push(
        this.#keywordTab("context", scope.tabLabel, this.session.contextResults)
      );
    }

    tabs.push({
      kind: "ask",
      icon: "far-discobot",
      label: i18n("discourse_ai.ai_search.tabs.ask"),
      empty: this.session.answerFailed,
      answered:
        Boolean(this.session.discoveries.streamedText) &&
        !this.session.answerFailed,
    });

    return tabs.map((tab) => ({
      ...tab,
      selected: this.session.selectedTab === tab.kind,
    }));
  }

  get tabsKey() {
    return this.tabs.map((tab) => tab.kind).join();
  }

  #keywordTab(kind, label, results) {
    const found = results?.posts?.length ?? 0;
    return {
      kind,
      icon: "magnifying-glass",
      label,
      count: results
        ? `${found}${results.grouped_search_result?.more_posts ? "+" : ""}`
        : null,
      empty: Boolean(results) && found === 0,
    };
  }

  <template>
    <div
      aria-label={{i18n "discourse_ai.ai_search.tabs.label"}}
      class="ai-discoveries-search-options ai-search-tabs"
      role="tablist"
      {{on "keydown" this.search.handleArrowUpOrDown}}
      {{dRovingFocus
        orientation="horizontal"
        itemSelector=".ai-discoveries-search-options__option"
        entryFocus="first"
        itemsKey=this.tabsKey
      }}
    >
      {{#each this.tabs key="kind" as |tab|}}
        <DButton
          aria-selected={{if tab.selected "true" "false"}}
          class={{dConcatClass
            "btn-default btn-small ai-discoveries-search-options__option"
            (concat "--" tab.kind)
            (if tab.selected "is-active")
            (if tab.empty "--empty")
          }}
          data-search-menu-navigation-item
          role="tab"
          @action={{fn this.session.selectTab tab.kind}}
          @icon={{tab.icon}}
          @translatedLabel={{tab.label}}
        >
          {{#if (eq tab.kind "ask")}}
            {{#if tab.empty}}
              <span
                class="ai-search-tabs__empty"
                title={{i18n "discourse_ai.ai_search.tabs.no_answer"}}
              >{{dIcon "ban"}}</span>
            {{else if tab.answered}}
              {{! the star that marks the AI's picks among the results }}
              <AiSearchBestMatch
                class="ai-search-tabs__answered"
                @label={{i18n "discourse_ai.ai_search.tabs.answered"}}
              />
            {{/if}}
          {{else if tab.count}}
            <span class="ai-search-tabs__count">{{tab.count}}</span>
          {{/if}}
        </DButton>
      {{/each}}
    </div>
  </template>
}
