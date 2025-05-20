import { Input } from "@ember/component";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import RouteTemplate from "ember-route-template";
import { or } from "truth-helpers";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import GoogleSearch from "discourse/components/google-search";
import LoadMore from "discourse/components/load-more";
import PluginOutlet from "discourse/components/plugin-outlet";
import SearchAdvancedOptions from "discourse/components/search-advanced-options";
import SearchResultEntries from "discourse/components/search-result-entries";
import SearchTextField from "discourse/components/search-text-field";
import TopicBulkSelectDropdown from "discourse/components/topic-list/topic-bulk-select-dropdown";
import UserLink from "discourse/components/user-link";
import avatar from "discourse/helpers/avatar";
import bodyClass from "discourse/helpers/body-class";
import categoryLink from "discourse/helpers/category-link";
import hideApplicationFooter from "discourse/helpers/hide-application-footer";
import htmlSafe from "discourse/helpers/html-safe";
import lazyHash from "discourse/helpers/lazy-hash";
import loadingSpinner from "discourse/helpers/loading-spinner";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

export default RouteTemplate(
  <template>
    {{#if @controller.loading}}
      {{hideApplicationFooter}}
    {{/if}}

    {{bodyClass "search-page"}}

    <section class="search-container">
      <PluginOutlet
        @name="full-page-search-above-search-header"
        @connectorTagName="div"
        @outletArgs={{lazyHash searchTerm=@controller.searchTerm}}
      />
      <div class="search-header" role="search">
        <h1 class="search-page-heading">
          {{#if @controller.hasResults}}
            <div
              class="result-count"
              id="search-result-count"
              aria-live="polite"
            >
              {{htmlSafe @controller.resultCountLabel}}
            </div>
          {{else}}
            <div class="search-page-heading__page-title">
              {{i18n "search.full_page_title"}}
            </div>
          {{/if}}
        </h1>
        <div class="search-bar">
          <SearchTextField
            @value={{@controller.searchTerm}}
            @aria-label={{i18n "search.search_term_label"}}
            @enter={{fn @controller.search (hash collapseFilters=true)}}
            @hasAutofocus={{@controller.hasAutofocus}}
            @aria-controls="search-result-count"
            type="search"
            class="full-page-search search no-blur search-query"
          />
          <ComboBox
            @id="search-type"
            @value={{@controller.search_type}}
            @content={{@controller.searchTypes}}
            @onChange={{fn (mut @controller.search_type)}}
            @options={{hash castInteger=true}}
          />
          <DButton
            @action={{fn @controller.search (hash collapseFilters=true)}}
            @icon="magnifying-glass"
            @label="search.search_button"
            @ariaLabel="search.search_button"
            @disabled={{@controller.searchButtonDisabled}}
            class="btn-primary search-cta"
          />
        </div>
        {{#if @controller.usingDefaultSearchType}}
          {{! context is only provided when searching from mobile view }}
          {{#if @controller.context}}
            <div class="search-context">
              <label>
                <Input
                  @type="checkbox"
                  name="searchContext"
                  @checked={{@controller.searchContextEnabled}}
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
                @searchTerm={{readonly @controller.searchTerm}}
                @onChangeSearchTerm={{fn (mut @controller.searchTerm)}}
                @search={{fn @controller.search (hash collapseFilters=true)}}
                @searchButtonDisabled={{@controller.searchButtonDisabled}}
                @expandFilters={{@controller.expandFilters}}
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
          @name="full-page-search-below-search-header"
          @connectorTagName="div"
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
              class={{@controller.searchInfoClassNames}}
              role="region"
              ariaLabel={{i18n "search.sort_or_bulk_actions"}}
            >
              {{#if @controller.canBulkSelect}}
                <DButton
                  @icon="list"
                  @title="topics.bulk.toggle"
                  @action={{@controller.toggleBulkSelect}}
                  class="btn-default bulk-select"
                />
                {{#if @controller.bulkSelectHelper.selected}}
                  <TopicBulkSelectDropdown
                    @bulkSelectHelper={{@controller.bulkSelectHelper}}
                    @afterBulkActionComplete={{@controller.afterBulkActionComplete}}
                  />
                {{/if}}
              {{/if}}

              {{#if @controller.bulkSelectEnabled}}
                {{#if @controller.hasUnselectedResults}}
                  <DButton
                    @icon="square-check"
                    @action={{@controller.selectAll}}
                    @label="search.select_all"
                    class="btn-default bulk-select-all"
                  />
                {{/if}}

                {{#if @controller.hasSelection}}
                  <DButton
                    @icon="far-square"
                    @action={{@controller.clearAll}}
                    @label="search.clear_all"
                    class="btn-default bulk-select-clear"
                  />
                {{/if}}
              {{/if}}

              <div class="sort-by inline-form">
                <label>
                  {{i18n "search.sort_by"}}
                </label>
                <ComboBox
                  @value={{@controller.sortOrder}}
                  @content={{@controller.sortOrders}}
                  @onChange={{@controller.setSortOrder}}
                  @id="search-sort-by"
                  @options={{hash castInteger=true}}
                />
              </div>
            </div>
          {{/if}}
        {{/if}}

        <PluginOutlet
          @name="full-page-search-below-search-info"
          @connectorTagName="div"
          @outletArgs={{lazyHash search=@controller.searchTerm}}
        />

        {{#if @controller.searching}}
          {{loadingSpinner size="medium"}}
        {{else}}
          <div class="search-results" role="region">
            <LoadMore @action={{@controller.loadMore}}>
              {{#if
                (or
                  @controller.usingDefaultSearchType
                  @controller.customSearchType
                )
              }}
                <SearchResultEntries
                  @posts={{@controller.searchResultPosts}}
                  @bulkSelectEnabled={{@controller.bulkSelectEnabled}}
                  @selected={{@controller.bulkSelectHelper.selected}}
                  @highlightQuery={{@controller.highlightQuery}}
                  @searchLogId={{@controller.model.grouped_search_result.search_log_id}}
                />

                <ConditionalLoadingSpinner @condition={{@controller.loading}}>
                  {{#if @controller.error}}
                    <div class="warning">
                      {{@controller.error}}
                    </div>
                  {{/if}}

                  {{#unless @controller.hasResults}}
                    {{#if @controller.searchActive}}
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
                                    @controller.createTopic
                                    @controller.searchTerm
                                  )
                                }}
                              >{{i18n "search.start_new_topic"}}</a>
                              {{#unless
                                @controller.siteSettings.login_required
                              }}
                                {{i18n "search.or_search_google"}}
                              {{/unless}}
                            {{else}}
                              {{i18n "search.search_google"}}
                            {{/if}}
                          </div>

                          <GoogleSearch
                            @searchTerm={{@controller.searchTerm}}
                          />
                        {{/if}}
                      </div>
                    {{/if}}
                  {{/unless}}

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
                </ConditionalLoadingSpinner>
              {{else}}
                <ConditionalLoadingSpinner @condition={{@controller.loading}}>
                  {{#if @controller.hasResults}}
                    {{#if @controller.model.categories.length}}
                      <h4 class="category-heading">
                        {{i18n "search.categories"}}
                      </h4>
                      <div class="category-items">
                        {{#each @controller.model.categories as |category|}}
                          {{categoryLink
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
                              {{tag.id}}
                            </a>
                          </div>
                        {{/each}}
                      </div>
                    {{/if}}

                    {{#if @controller.model.users}}
                      <div class="user-items">
                        {{#each @controller.model.users as |user|}}
                          <UserLink @user={{user}} class="fps-user-item">
                            {{avatar user imageSize="large"}}

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
                          </UserLink>
                        {{/each}}
                      </div>
                    {{/if}}
                  {{else}}
                    {{#if @controller.searchActive}}
                      <h3>{{i18n "search.no_results"}}</h3>
                    {{/if}}
                  {{/if}}
                </ConditionalLoadingSpinner>
              {{/if}}
              <PluginOutlet
                @name="full-page-search-below-results"
                @outletArgs={{lazyHash canLoadMore=@controller.canLoadMore}}
              />
            </LoadMore>
          </div>
        {{/if}}
      </div>
    </section>
  </template>
);
