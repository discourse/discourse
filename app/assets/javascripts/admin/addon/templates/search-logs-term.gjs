import { fn, hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import RouteTemplate from "ember-route-template";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import HighlightSearch from "discourse/components/highlight-search";
import TopicStatus from "discourse/components/topic-status";
import ageWithTooltip from "discourse/helpers/age-with-tooltip";
import avatar from "discourse/helpers/avatar";
import categoryLink from "discourse/helpers/category-link";
import discourseTag from "discourse/helpers/discourse-tag";
import htmlSafe from "discourse/helpers/html-safe";
import { i18n } from "discourse-i18n";
import Chart from "admin/components/chart";
import ComboBox from "select-kit/components/combo-box";
import PeriodChooser from "select-kit/components/period-chooser";

export default RouteTemplate(
  <template>
    <div class="admin-title">
      <PeriodChooser
        @period={{@controller.period}}
        @onChange={{fn (mut @controller.period)}}
      />
      <ComboBox
        @content={{@controller.searchTypeOptions}}
        @value={{@controller.searchType}}
        @onChange={{fn (mut @controller.searchType)}}
        class="search-logs-filter"
      />
    </div>

    <h2>
      <LinkTo
        @route="full-page-search"
        @query={{hash q=@controller.term}}
      >{{@controller.term}}</LinkTo>
    </h2>

    <ConditionalLoadingSpinner @condition={{@controller.refreshing}}>
      <Chart @chartConfig={{@controller.chartConfig}} />

      <br /><br />
      <h2> {{i18n "admin.logs.search_logs.header_search_results"}} </h2>
      <br />

      <div class="header-search-results">
        {{#each @controller.model.search_result.posts as |result|}}
          <div class="fps-result">
            <div class="author">
              <a href={{result.userPath}} data-user-card={{result.username}}>
                {{avatar result imageSize="large"}}
              </a>
            </div>

            <div class="fps-topic">
              <div class="topic">
                <a href={{result.url}} class="search-link">
                  <TopicStatus
                    @topic={{result.topic}}
                    @disableActions={{true}}
                  />
                  <span class="topic-title">
                    {{#if result.useTopicTitleHeadline}}
                      {{htmlSafe result.topicTitleHeadline}}
                    {{else}}
                      <HighlightSearch @highlight={{@controller.q}}>
                        {{htmlSafe result.topic.fancyTitle}}
                      </HighlightSearch>
                    {{/if}}
                  </span>
                </a>

                <div class="search-category">
                  {{#if result.topic.category.parentCategory}}
                    {{categoryLink result.topic.category.parentCategory}}
                  {{/if}}
                  {{categoryLink result.topic.category hideParent=true}}
                  {{#each result.topic.tags as |tag|}}
                    {{discourseTag tag}}
                  {{/each}}
                </div>
              </div>

              <div class="blurb container">
                <span class="date">
                  {{ageWithTooltip result.created_at}}
                  {{#if result.blurb}}
                    -
                  {{/if}}
                </span>

                {{#if result.blurb}}
                  {{#if @controller.siteSettings.use_pg_headlines_for_excerpt}}
                    {{htmlSafe result.blurb}}
                  {{else}}
                    <HighlightSearch @highlight={{@controller.highlightQuery}}>
                      {{htmlSafe result.blurb}}
                    </HighlightSearch>
                  {{/if}}
                {{/if}}
              </div>
            </div>
          </div>
        {{/each}}
      </div>
    </ConditionalLoadingSpinner>
  </template>
);
