import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import { and, not } from "truth-helpers";
import ConditionalLoadingSection from "discourse/components/conditional-loading-section";
import PluginOutlet from "discourse/components/plugin-outlet";
import Assistant from "discourse/components/search-menu/results/assistant";
import InitialOptions from "discourse/components/search-menu/results/initial-options";
import MoreLink from "discourse/components/search-menu/results/more-link";
import Types from "discourse/components/search-menu/results/types";
import lazyHash from "discourse/helpers/lazy-hash";
import { i18n } from "discourse-i18n";
import CategoryViewComponent from "./results/type/category";
import GroupViewComponent from "./results/type/group";
import PostViewComponent from "./results/type/post";
import TagViewComponent from "./results/type/tag";
import TopicViewComponent from "./results/type/topic";
import UserViewComponent from "./results/type/user";

const SEARCH_RESULTS_COMPONENT_TYPE = {
  "search-result-category": CategoryViewComponent,
  "search-result-topic": TopicViewComponent,
  "search-result-post": PostViewComponent,
  "search-result-user": UserViewComponent,
  "search-result-tag": TagViewComponent,
  "search-result-group": GroupViewComponent,
};

export default class Results extends Component {
  @service search;

  @tracked searchTopics = this.args.searchTopics;

  get renderInitialOptions() {
    return !this.search.activeGlobalSearchTerm && !this.args.inPMInboxContext;
  }

  get noTopicResults() {
    return this.args.searchTopics && this.search.noResults;
  }

  get termTooShort() {
    return this.args.searchTopics && this.args.invalidTerm;
  }

  get resultTypesWithComponent() {
    let content = [];
    this.search.results.resultTypes?.map((resultType) => {
      content.push({
        ...resultType,
        component: SEARCH_RESULTS_COMPONENT_TYPE[resultType.componentName],
      });
    });
    return content;
  }

  get searchLogId() {
    return this.search.results.grouped_search_result?.search_log_id;
  }

  get inTopicContext() {
    return this.search.inTopicContext && !this.args.searchTopics;
  }

  <template>
    {{#unless this.inTopicContext}}
      <ConditionalLoadingSection @isLoading={{this.loading}}>
        <div class="results">
          <PluginOutlet
            @name="search-menu-results-top"
            @outletArgs={{lazyHash
              closeSearchMenu=@closeSearchMenu
              searchTerm=this.search.activeGlobalSearchTerm
              inTopicContext=this.search.inTopicContext
              searchTopics=@searchTopics
            }}
          />
          {{#if @suggestionKeyword}}
            <Assistant
              @suggestionKeyword={{@suggestionKeyword}}
              @results={{@suggestionResults}}
              @closeSearchMenu={{@closeSearchMenu}}
              @searchTermChanged={{@searchTermChanged}}
            />
          {{else if this.termTooShort}}
            <div class="no-results">{{i18n "search.too_short"}}</div>
          {{else if this.noTopicResults}}
            <div class="no-results">{{i18n "search.no_results"}}</div>
          {{else if this.renderInitialOptions}}
            <InitialOptions
              @searchInputId={{@searchInputId}}
              @closeSearchMenu={{@closeSearchMenu}}
              @searchTermChanged={{@searchTermChanged}}
            />
          {{else}}
            {{#if (and (not @searchTopics) (not @inPMInboxContext))}}
              {{! render the first couple suggestions before a search has been performed}}
              <InitialOptions
                @searchInputId={{@searchInputId}}
                @closeSearchMenu={{@closeSearchMenu}}
                @searchTermChanged={{@searchTermChanged}}
              />
            {{/if}}

            {{#if (and @searchTopics this.resultTypesWithComponent)}}
              {{! render results after a search has been performed }}
              <Types
                @resultTypes={{this.resultTypesWithComponent}}
                @topicResultsOnly={{true}}
                @closeSearchMenu={{@closeSearchMenu}}
                @searchLogId={{this.searchLogId}}
              />
              <MoreLink
                @updateTypeFilter={{@updateTypeFilter}}
                @triggerSearch={{@triggerSearch}}
                @resultTypes={{this.resultTypesWithComponent}}
                @closeSearchMenu={{@closeSearchMenu}}
                @searchTermChanged={{@searchTermChanged}}
              />
            {{else if
              (and
                (not @inPMInboxContext)
                (not @searchTopics)
                this.resultTypesWithComponent
              )
            }}
              <Types
                @resultTypes={{this.resultTypesWithComponent}}
                @closeSearchMenu={{@closeSearchMenu}}
                @searchTermChanged={{@searchTermChanged}}
                @displayNameWithUser={{true}}
                @searchLogId={{this.searchLogId}}
              />
            {{/if}}
            <PluginOutlet
              @name="search-menu-with-results-bottom"
              @outletArgs={{lazyHash resultTypes=this.resultTypesWithComponent}}
            />
          {{/if}}
          <PluginOutlet
            @name="search-menu-results-bottom"
            @outletArgs={{lazyHash
              inTopicContext=this.search.inTopicContext
              searchTermChanged=@searchTermChanged
              searchTopics=@searchTopics
              closeSearchMenu=@closeSearchMenu
            }}
          />
        </div>
      </ConditionalLoadingSection>
    {{/unless}}
  </template>
}
