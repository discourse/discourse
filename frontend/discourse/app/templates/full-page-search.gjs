import { Input } from "@ember/component";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { trustHTML } from "@ember/template";
import GoogleSearch from "discourse/components/google-search";
import PluginOutlet from "discourse/components/plugin-outlet";
import SearchAdvancedOptions from "discourse/components/search-advanced-options";
import SearchBulkSelectDropdown from "discourse/components/search-bulk-select-dropdown";
import ClearButton from "discourse/components/search-menu/clear-button";
import SearchResultEntries from "discourse/components/search-result-entries";
import SearchTextField from "discourse/components/search-text-field";
import bodyClass from "discourse/helpers/body-class";
import hideApplicationFooter from "discourse/helpers/hide-application-footer";
import lazyHash from "discourse/helpers/lazy-hash";
import ComboBox from "discourse/select-kit/components/combo-box";
import { eq, or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DHorizontalOverflowNav from "discourse/ui-kit/d-horizontal-overflow-nav";
import DLoadMore from "discourse/ui-kit/d-load-more";
import DUserLink from "discourse/ui-kit/d-user-link";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dCategoryLink from "discourse/ui-kit/helpers/d-category-link";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dLoadingSpinner from "discourse/ui-kit/helpers/d-loading-spinner";
import { i18n } from "discourse-i18n";

export default <template>
  {{#if @controller.loading}}
    {{hideApplicationFooter}}
  {{/if}}

  {{bodyClass "search-page"}}

  <section class="search-container">
    <PluginOutlet
      @connectorTagName="div"
      @name="full-page-search-above-search-header"
      @outletArgs={{lazyHash searchTerm=@controller.searchTerm}}
    />
    <div class="search-header" role="search">
      {{! the page announces itself to a screen reader, but the types above the
          field are what say what this page is to everyone else }}
      <h1 class="search-page-heading sr-only">
        {{i18n "search.full_page_title"}}
      </h1>

      <DHorizontalOverflowNav
        class="search-types"
        @ariaLabel={{i18n "search.type.label"}}
      >
        {{#each @controller.searchTypes key="id" as |searchType|}}
          <li>
            {{! a plain button, not a DButton: the nav styles this element
                directly, and the button classes would fight them }}
            <button
              class={{dConcatClass
                "search-types__type"
                (if (eq @controller.activeSearchType searchType.id) "active")
              }}
              data-search-type={{searchType.id}}
              type="button"
              {{on "click" (fn @controller.setSearchType searchType.id)}}
            >{{searchType.name}}</button>
          </li>
        {{/each}}
      </DHorizontalOverflowNav>

      <div class="search-bar">
        <div class="search-bar__field">
          <SearchTextField
            class="full-page-search search no-blur search-query"
            type="search"
            @aria-label={{i18n "search.search_term_label"}}
            @enter={{fn @controller.search (hash collapseFilters=true)}}
            @hasAutofocus={{@controller.hasAutofocus}}
            @value={{@controller.searchTerm}}
          />

          {{#if @controller.searchTerm}}
            <ClearButton @clearSearch={{@controller.clearSearchTerm}} />
          {{/if}}
        </div>
        <DButton
          class="btn-primary search-cta"
          @action={{fn @controller.search (hash collapseFilters=true)}}
          @ariaLabel={{@controller.searchButtonLabel}}
          @disabled={{@controller.searchButtonDisabled}}
          @icon={{@controller.searchButtonIcon}}
          @label={{@controller.searchButtonLabel}}
        />
      </div>

      {{#if @controller.usingDefaultSearchType}}
        {{! context is only provided when searching from mobile view }}
        {{#if @controller.context}}
          <div class="search-context">
            <label>
              <Input
                name="searchContext"
                @checked={{@controller.searchContextEnabled}}
                @type="checkbox"
              />
              {{@controller.searchContextDescription}}
            </label>
          </div>
        {{/if}}

        <div class="search-filters">
          <PluginOutlet
            @name="full-page-search-filters"
            @outletArgs={{lazyHash
              searchTerm=(readonly @controller.searchTerm)
              onChangeSearchTerm=(fn (mut @controller.searchTerm))
              search=(fn @controller.search (hash collapseFilters=true))
              searchButtonDisabled=@controller.searchButtonDisabled
              expandFilters=@controller.expandFilters
              sortOrder=@controller.sortOrder
              sortOrderOptions=@controller.sortOrders
              setSortOrder=@controller.setSortOrder
              type=@controller.search_type
              addSearchResults=@controller.addSearchResults
              resultCount=@controller.resultCount
            }}
          >
            <SearchAdvancedOptions
              @addSearchResults={{@controller.addSearchResults}}
              @expandFilters={{@controller.expandFilters}}
              @model={{@controller.model}}
              @onChangeSearchTerm={{fn (mut @controller.searchTerm)}}
              @search={{fn @controller.search (hash collapseFilters=true)}}
              @searchButtonDisabled={{@controller.searchButtonDisabled}}
              @searchTerm={{readonly @controller.searchTerm}}
              @searchType={{@controller.search_type}}
              @sortOrder={{@controller.sortOrder}}
            />
          </PluginOutlet>
        </div>
      {{/if}}

      <div class="search-notice">
        {{#if @controller.invalidSearch}}
          <div class="fps-invalid">
            {{i18n "search.too_short"}}
          </div>
        {{/if}}
      </div>

    </div>

    <div class="search-advanced">
      <PluginOutlet
        @connectorTagName="div"
        @name="full-page-search-below-search-header"
        @outletArgs={{lazyHash
          search=@controller.searchTerm
          type=@controller.search_type
          model=@controller.model
          addSearchResults=@controller.addSearchResults
          sortOrder=@controller.sortOrder
        }}
      />

      {{#if @controller.hasResults}}
        {{#if @controller.usingDefaultSearchType}}
          <div
            ariaLabel={{i18n "search.sort_or_bulk_actions"}}
            class={{@controller.searchInfoClassNames}}
            role="region"
          >
            {{#if @controller.canBulkSelect}}
              <DButton
                class="btn-default bulk-select"
                @action={{@controller.toggleBulkSelect}}
                @icon="list"
                @title="topics.bulk.toggle"
              />
            {{/if}}
            {{#if @controller.bulkSelectEnabled}}
              {{#if @controller.hasUnselectedResults}}
                <DButton
                  class="btn-default bulk-select-all"
                  @action={{@controller.selectAll}}
                  @icon="square-check"
                  @label="search.select_all"
                />
              {{/if}}

              {{#if @controller.hasSelection}}
                <DButton
                  class="btn-default bulk-select-clear"
                  @action={{@controller.clearAll}}
                  @icon="far-square"
                  @label="search.clear_all"
                />
              {{/if}}
            {{/if}}
            {{#if @controller.canBulkSelect}}
              {{#if @controller.bulkSelectHelper.selected}}
                <SearchBulkSelectDropdown
                  @afterBulkActionComplete={{@controller.afterBulkActionComplete}}
                  @bulkSelectHelper={{@controller.bulkSelectHelper}}
                />
              {{/if}}
            {{/if}}

            <div class="sort-by inline-form">
              <label>
                {{i18n "search.sort_by"}}
              </label>
              <ComboBox
                @content={{@controller.sortOrders}}
                @id="search-sort-by"
                @onChange={{@controller.setSortOrder}}
                @options={{hash castInteger=true}}
                @value={{@controller.sortOrder}}
              />
            </div>
          </div>
        {{/if}}

        <h2 aria-live="polite" class="result-count" id="search-result-count">
          {{trustHTML @controller.resultCountLabel}}
        </h2>
      {{/if}}

      <PluginOutlet
        @connectorTagName="div"
        @name="full-page-search-below-search-info"
        @outletArgs={{lazyHash search=@controller.searchTerm}}
      />

      {{#if @controller.searching}}
        {{dLoadingSpinner size="medium"}}
      {{else}}
        <div
          aria-label={{if
            @controller.q
            (i18n "search.results_page" term=@controller.q)
            (i18n "search.results")
          }}
          class="search-results"
          role="region"
        >
          <DLoadMore @action={{@controller.loadMore}}>
            {{#if
              (or
                @controller.usingDefaultSearchType @controller.customSearchType
              )
            }}
              <PluginOutlet
                @connectorTagName="div"
                @name="full-page-search-before-results"
                @outletArgs={{lazyHash
                  model=@controller.model
                  searchTerm=@controller.searchTerm
                }}
              />
              <SearchResultEntries
                @bulkSelectEnabled={{@controller.bulkSelectEnabled}}
                @highlightQuery={{@controller.highlightQuery}}
                @isPMOnly={{@controller.isPMOnly}}
                @posts={{@controller.searchResultPosts}}
                @searchLogId={{@controller.model.grouped_search_result.search_log_id}}
                @selected={{@controller.bulkSelectHelper.selected}}
              />

              <DConditionalLoadingSpinner @condition={{@controller.loading}}>
                {{#if @controller.error}}
                  <div class="warning">
                    {{@controller.error}}
                  </div>
                {{/if}}

                {{#if @controller.showNoResults}}
                  <div class="no-results-container">
                    <h3>{{i18n "search.no_results"}}</h3>

                    {{#if @controller.showSuggestion}}
                      <div class="no-results-suggestion">
                        {{i18n "search.cant_find"}}
                        {{#if @controller.canCreateTopic}}
                          <a
                            href
                            {{on
                              "click"
                              (fn
                                @controller.createTopic @controller.searchTerm
                              )
                            }}
                          >{{i18n "search.start_new_topic"}}</a>
                          {{#unless @controller.siteSettings.login_required}}
                            {{i18n "search.or_search_google"}}
                          {{/unless}}
                        {{else}}
                          {{i18n "search.search_google"}}
                        {{/if}}
                      </div>

                      <GoogleSearch @searchTerm={{@controller.searchTerm}} />
                    {{/if}}
                  </div>
                {{/if}}

                {{#if @controller.hasResults}}
                  <h3 class="search-footer">
                    {{#if
                      @controller.model.grouped_search_result.more_full_page_results
                    }}
                      {{#if @controller.isLastPage}}
                        {{i18n "search.more_results"}}
                      {{/if}}
                    {{else}}
                      {{i18n "search.no_more_results"}}
                    {{/if}}
                  </h3>
                {{/if}}
              </DConditionalLoadingSpinner>
            {{else}}
              <DConditionalLoadingSpinner @condition={{@controller.loading}}>
                {{#if @controller.hasResults}}
                  {{#if @controller.model.categories.length}}
                    <h4 class="category-heading">
                      {{i18n "search.categories"}}
                    </h4>
                    <div class="category-items">
                      {{#each @controller.model.categories as |category|}}
                        {{dCategoryLink
                          category
                          extraClasses="fps-category-item"
                        }}
                      {{/each}}
                    </div>
                  {{/if}}

                  {{#if @controller.model.tags.length}}
                    <h4 class="tag-heading">
                      {{i18n "search.tags"}}
                    </h4>

                    <div class="tag-items">
                      {{#each @controller.model.tags as |tag|}}
                        <div class="fps-tag-item">
                          <a href={{tag.url}}>
                            {{tag.name}}
                          </a>
                        </div>
                      {{/each}}
                    </div>
                  {{/if}}

                  {{#if @controller.model.users}}
                    <div class="user-items">
                      {{#each @controller.model.users as |user|}}
                        <DUserLink class="fps-user-item" @user={{user}}>
                          {{dAvatar user imageSize="large"}}

                          <div class="user-titles">
                            {{#if user.name}}
                              <span class="name">
                                {{user.name}}
                              </span>
                            {{/if}}

                            <span class="username">
                              {{user.username}}
                            </span>
                          </div>
                        </DUserLink>
                      {{/each}}
                    </div>
                  {{/if}}
                {{else}}
                  {{#if @controller.searchActive}}
                    <h3>{{i18n "search.no_results"}}</h3>
                  {{/if}}
                {{/if}}
              </DConditionalLoadingSpinner>
            {{/if}}
            <PluginOutlet
              @name="full-page-search-below-results"
              @outletArgs={{lazyHash canLoadMore=@controller.canLoadMore}}
            />
          </DLoadMore>
        </div>
      {{/if}}
    </div>
  </section>
</template>
