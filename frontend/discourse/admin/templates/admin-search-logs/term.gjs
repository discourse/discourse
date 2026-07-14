import { fn, hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import { trustHTML } from "@ember/template";
import Chart from "discourse/admin/components/chart";
import HighlightSearch from "discourse/components/highlight-search";
import TopicStatus from "discourse/components/topic-status";
import ComboBox from "discourse/select-kit/components/combo-box";
import PeriodChooser from "discourse/select-kit/components/period-chooser";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import dAgeWithTooltip from "discourse/ui-kit/helpers/d-age-with-tooltip";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dCategoryLink from "discourse/ui-kit/helpers/d-category-link";
import dDiscourseTag from "discourse/ui-kit/helpers/d-discourse-tag";
import { i18n } from "discourse-i18n";

export default <template>
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

  <DConditionalLoadingSpinner @condition={{@controller.refreshing}}>
    <Chart @chartConfig={{@controller.chartConfig}} />

    <br /><br />
    <h2> {{i18n "admin.logs.search_logs.header_search_results"}} </h2>
    <br />

    <div class="header-search-results">
      {{#each @controller.model.search_result.posts as |result|}}
        <div class="fps-result">
          <div class="author">
            <a href={{result.userPath}} data-user-card={{result.username}}>
              {{dAvatar result imageSize="large"}}
            </a>
          </div>

          <div class="fps-topic">
            <div class="topic">
              <a href={{result.url}} class="search-link">
                <TopicStatus @topic={{result.topic}} @disableActions={{true}} />
                <span class="topic-title">
                  {{#if result.useTopicTitleHeadline}}
                    {{trustHTML result.topicTitleHeadline}}
                  {{else}}
                    <HighlightSearch @highlight={{@controller.q}}>
                      {{trustHTML result.topic.fancyTitle}}
                    </HighlightSearch>
                  {{/if}}
                </span>
              </a>

              <div class="search-category">
                {{#if result.topic.category.parentCategory}}
                  {{dCategoryLink result.topic.category.parentCategory}}
                {{/if}}
                {{dCategoryLink result.topic.category hideParent=true}}
                {{#each result.topic.tags as |tag|}}
                  {{dDiscourseTag tag}}
                {{/each}}
              </div>
            </div>

            <div class="blurb container">
              <span class="date">
                {{dAgeWithTooltip result.created_at}}
                {{#if result.blurb}}
                  -
                {{/if}}
              </span>

              {{#if result.blurb}}
                {{#if @controller.siteSettings.use_pg_headlines_for_excerpt}}
                  {{trustHTML result.blurb}}
                {{else}}
                  <HighlightSearch @highlight={{@controller.highlightQuery}}>
                    {{trustHTML result.blurb}}
                  </HighlightSearch>
                {{/if}}
              {{/if}}
            </div>
          </div>
        </div>
      {{/each}}
    </div>
  </DConditionalLoadingSpinner>
</template>
