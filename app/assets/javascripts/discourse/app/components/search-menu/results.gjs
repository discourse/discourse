{{#if (and this.search.inTopicContext (not @searchTopics))}}
  <SearchMenu::BrowserSearchTip />
{{else}}
  <ConditionalLoadingSection @isLoading={{this.loading}}>
    <div class="results">
      <PluginOutlet
        @name="search-menu-results-top"
        @outletArgs={{hash
          closeSearchMenu=@closeSearchMenu
          searchTerm=this.search.activeGlobalSearchTerm
          inTopicContext=this.search.inTopicContext
          searchTopics=@searchTopics
        }}
      />
      {{#if @suggestionKeyword}}
        <SearchMenu::Results::Assistant
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
        <SearchMenu::Results::InitialOptions
          @closeSearchMenu={{@closeSearchMenu}}
          @searchTermChanged={{@searchTermChanged}}
        />
      {{else}}
        {{#if (and (not @searchTopics) (not @inPMInboxContext))}}
          {{! render the first couple suggestions before a search has been performed}}
          <SearchMenu::Results::InitialOptions
            @closeSearchMenu={{@closeSearchMenu}}
            @searchTermChanged={{@searchTermChanged}}
          />
        {{/if}}

        {{#if (and @searchTopics this.resultTypesWithComponent)}}
          {{! render results after a search has been performed }}
          <SearchMenu::Results::Types
            @resultTypes={{this.resultTypesWithComponent}}
            @topicResultsOnly={{true}}
            @closeSearchMenu={{@closeSearchMenu}}
            @searchLogId={{this.searchLogId}}
          />
          <SearchMenu::Results::MoreLink
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
          <SearchMenu::Results::Types
            @resultTypes={{this.resultTypesWithComponent}}
            @closeSearchMenu={{@closeSearchMenu}}
            @searchTermChanged={{@searchTermChanged}}
            @displayNameWithUser={{true}}
            @searchLogId={{this.searchLogId}}
          />
        {{/if}}
        <PluginOutlet
          @name="search-menu-with-results-bottom"
          @outletArgs={{hash resultTypes=this.resultTypesWithComponent}}
        />
      {{/if}}
      <PluginOutlet
        @name="search-menu-results-bottom"
        @outletArgs={{hash
          inTopicContext=this.search.inTopicContext
          searchTermChanged=@searchTermChanged
          searchTopics=@searchTopics
          closeSearchMenu=@closeSearchMenu
        }}
      />
    </div>
  </ConditionalLoadingSection>
{{/if}}