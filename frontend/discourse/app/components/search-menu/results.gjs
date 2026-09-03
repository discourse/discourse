import Component from "@glimmer/component";
import { service } from "@ember/service";
import PluginOutlet from "discourse/components/plugin-outlet";
import Assistant from "discourse/components/search-menu/results/assistant";
import InitialOptions from "discourse/components/search-menu/results/initial-options";
import MoreLink from "discourse/components/search-menu/results/more-link";
import Types from "discourse/components/search-menu/results/types";
import lazyHash from "discourse/helpers/lazy-hash";
import { applyValueTransformer } from "discourse/lib/transformer";
import { and, not } from "discourse/truth-helpers";
import DConditionalLoadingSection from "discourse/ui-kit/d-conditional-loading-section";
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

  // The list resolved from the index; a consumer answering the same term another
  // way takes over the space until it has nothing to offer.
  get showIndexedResults() {
    return applyValueTransformer("search-menu-indexed-results-enabled", true, {
      location: this.args.location,
    });
  }

  get inTopicContext() {
    return this.search.inTopicContext && !this.args.searchTopics;
  }

  <template>
    <DConditionalLoadingSection @isLoading={{this.loading}}>
      <div class="results">
        {{! outside the topic-context guard below: a consumer offering scope as a
            choice needs somewhere to offer the way back out of one }}
        <PluginOutlet
          @name="search-menu-results-top"
          @outletArgs={{lazyHash
            closeSearchMenu=@closeSearchMenu
            location=@location
            searchTerm=this.search.activeGlobalSearchTerm
            inTopicContext=this.search.inTopicContext
            inPMInboxContext=@inPMInboxContext
            clearPMInboxContext=@clearPMInboxContext
            searchTopics=@searchTopics
            triggerSearch=@triggerSearch
            updateTypeFilter=@updateTypeFilter
            openAdvancedSearch=@openAdvancedSearch
            searchTermChanged=@searchTermChanged
            clearTopicContext=@clearTopicContext
          }}
        />
        {{#unless this.inTopicContext}}
          {{#if (and @suggestionKeyword this.showIndexedResults)}}
            <Assistant
              @suggestionKeyword={{@suggestionKeyword}}
              @results={{@suggestionResults}}
              @closeSearchMenu={{@closeSearchMenu}}
              @searchTermChanged={{@searchTermChanged}}
            />
          {{else if this.termTooShort}}
            <div class="no-results">{{i18n "search.too_short"}}</div>
          {{else if (and this.noTopicResults this.showIndexedResults)}}
            <div class="no-results">{{i18n "search.no_results"}}</div>
          {{else if this.renderInitialOptions}}
            <InitialOptions
              @location={{@location}}
              @searchInputId={{@searchInputId}}
              @closeSearchMenu={{@closeSearchMenu}}
              @searchTermChanged={{@searchTermChanged}}
            />
          {{else}}
            {{#if
              (and
                this.showIndexedResults
                (not @searchTopics)
                (not @inPMInboxContext)
              )
            }}
              {{! render the first couple suggestions before a search has been performed}}
              <InitialOptions
                @location={{@location}}
                @searchInputId={{@searchInputId}}
                @closeSearchMenu={{@closeSearchMenu}}
                @searchTermChanged={{@searchTermChanged}}
              />
            {{/if}}

            {{#if
              (and
                this.showIndexedResults
                @searchTopics
                this.resultTypesWithComponent
              )
            }}
              {{! render results after a search has been performed }}
              <Types
                @resultTypes={{this.resultTypesWithComponent}}
                @topicResultsOnly={{true}}
                @closeSearchMenu={{@closeSearchMenu}}
                @searchLogId={{this.searchLogId}}
                @isPMOnly={{@isPMOnly}}
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
                this.showIndexedResults
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
                @isPMOnly={{@isPMOnly}}
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
        {{/unless}}
      </div>
    </DConditionalLoadingSection>
  </template>
}
