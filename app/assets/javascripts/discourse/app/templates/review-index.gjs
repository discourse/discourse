import { fn, hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import RouteTemplate from "ember-route-template";
import { eq } from "truth-helpers";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import DateTimeInputRange from "discourse/components/date-time-input-range";
import LoadMore from "discourse/components/load-more";
import PluginOutlet from "discourse/components/plugin-outlet";
import ReviewableItem from "discourse/components/reviewable-item";
import icon from "discourse/helpers/d-icon";
import htmlSafe from "discourse/helpers/html-safe";
import lazyHash from "discourse/helpers/lazy-hash";
import { i18n } from "discourse-i18n";
import CategoryChooser from "select-kit/components/category-chooser";
import ComboBox from "select-kit/components/combo-box";
import EmailGroupUserChooser from "select-kit/components/email-group-user-chooser";

export default RouteTemplate(
  <template>
    {{#if @controller.displayUnknownReviewableTypesWarning}}
      <div class="alert alert-info unknown-reviewables">
        <span class="text">{{i18n
            "review.unknown.title"
            count=@controller.unknownReviewableTypes.length
          }}</span>

        <ul>
          {{#each @controller.unknownReviewableTypes as |reviewable|}}
            {{#if (eq reviewable.source @controller.unknownTypeSource)}}
              <li>{{i18n
                  "review.unknown.reviewable_unknown_source"
                  reviewableType=reviewable.type
                }}</li>
            {{else}}
              <li>{{i18n
                  "review.unknown.reviewable_known_source"
                  reviewableType=reviewable.type
                  pluginName=reviewable.source
                }}</li>
            {{/if}}
          {{/each}}
        </ul>
        <span class="text">{{htmlSafe
            (i18n
              "review.unknown.instruction"
              url="https://meta.discourse.org/t/350179"
            )
          }}</span>
        <div class="unknown-reviewables__options">
          <LinkTo @route="adminPlugins.index" class="btn">
            {{icon "puzzle-piece"}}
            <span>{{i18n "review.unknown.enable_plugins"}}</span>
          </LinkTo>
          <DButton
            @label="review.unknown.ignore_all"
            @icon="trash-can"
            @action={{@controller.ignoreAllUnknownTypes}}
            class="btn-default"
          />
        </div>
      </div>
    {{/if}}
    <div class="reviewable-container">
      <div class="reviewable-list">
        {{#if @controller.reviewables}}
          <LoadMore @action={{@controller.loadMore}}>
            <div class="reviewables">
              {{#each @controller.reviewables as |r|}}
                <ReviewableItem
                  @reviewable={{r}}
                  @remove={{@controller.remove}}
                />
              {{/each}}
            </div>
          </LoadMore>
          <ConditionalLoadingSpinner
            @condition={{@controller.reviewables.loadingMore}}
          />
        {{else}}
          <div class="no-review">
            {{i18n "review.none"}}
          </div>
        {{/if}}
      </div>

      <div class="reviewable-filters">
        <div class="reviewable-filter">
          <label class="filter-label">
            {{i18n "review.filters.status"}}
          </label>
          <ComboBox
            @value={{@controller.filterStatus}}
            @content={{@controller.statuses}}
            @onChange={{fn (mut @controller.filterStatus)}}
          />
        </div>

        {{#if @controller.filtersExpanded}}

          <span>
            <PluginOutlet
              @name="above-review-filters"
              @connectorTagName="div"
              @outletArgs={{lazyHash
                model=@controller.model
                additionalFilters=@controller.additionalFilters
              }}
            />
          </span>

          <div class="reviewable-filter">
            <label class="filter-label">
              {{i18n "review.filters.type.title"}}
            </label>
            <ComboBox
              @value={{@controller.filterType}}
              @content={{@controller.allTypes}}
              @onChange={{fn (mut @controller.filterType)}}
              @options={{hash none="review.filters.type.all"}}
            />
          </div>

          <div class="reviewable-filter">
            <label class="filter-label">
              {{i18n "review.filters.score_type.title"}}
            </label>
            <ComboBox
              @value={{@controller.filterScoreType}}
              @content={{@controller.allScoreTypes}}
              @onChange={{fn (mut @controller.filterScoreType)}}
              @options={{hash none="review.filters.score_type.all"}}
            />
          </div>

          <div class="reviewable-filter">
            <label class="filter-label">
              {{i18n "review.filters.priority.title"}}
            </label>
            <ComboBox
              @value={{@controller.filterPriority}}
              @content={{@controller.priorities}}
              @onChange={{fn (mut @controller.filterPriority)}}
            />
          </div>

          <div class="reviewable-filter">
            <label class="filter-label">
              {{i18n "review.filters.category"}}
            </label>
            <CategoryChooser
              @value={{@controller.filterCategoryId}}
              @onChange={{fn (mut @controller.filterCategoryId)}}
              @options={{hash
                none="review.filters.all_categories"
                clearable=true
              }}
            />
          </div>

          <div class="reviewable-filter topic-filter">
            <label class="filter-label">
              {{i18n "review.filtered_flagged_by"}}
            </label>
            <EmailGroupUserChooser
              @value={{@controller.filterFlaggedBy}}
              @onChange={{@controller.updateFilterFlaggedBy}}
              @options={{hash
                maximum=1
                excludeCurrentUser=false
                fullWidthWrap=true
              }}
            />
          </div>

          <div class="reviewable-filter topic-filter">
            <label class="filter-label">
              {{i18n "review.filtered_reviewed_by"}}
            </label>
            <EmailGroupUserChooser
              @value={{@controller.filterReviewedBy}}
              @onChange={{@controller.updateFilterReviewedBy}}
              @options={{hash
                maximum=1
                excludeCurrentUser=false
                fullWidthWrap=true
              }}
            />
          </div>

          <div class="reviewable-filter topic-filter">
            <label class="filter-label">
              {{i18n "review.filtered_user"}}
            </label>
            <EmailGroupUserChooser
              @value={{@controller.filterUsername}}
              @onChange={{@controller.updateFilterUsername}}
              @options={{hash
                maximum=1
                excludeCurrentUser=false
                fullWidthWrap=true
              }}
              class="user-selector"
            />
          </div>

          {{#if @controller.filterTopic}}
            <div class="reviewable-filter topic-filter">
              <label class="filter-label">
                {{i18n "review.filtered_topic"}}
              </label>
              <DButton
                @label="review.show_all_topics"
                @icon="xmark"
                @action={{@controller.resetTopic}}
                class="btn-default"
              />
            </div>
          {{/if}}

          <div class="reviewable-filter date-range">
            <label class="filter-label">
              {{i18n "review.date_filter"}}
            </label>
            <DateTimeInputRange
              @from={{@controller.filterFromDate}}
              @to={{@controller.filterToDate}}
              @onChange={{@controller.setRange}}
              @showFromTime={{false}}
              @showToTime={{false}}
            />
          </div>

          <div class="reviewable-filter sort-order">
            <label class="filter-label">
              {{i18n "review.order_by"}}
            </label>
            <ComboBox
              @value={{@controller.filterSortOrder}}
              @content={{@controller.sortOrders}}
              @onChange={{fn (mut @controller.filterSortOrder)}}
            />
          </div>
        {{/if}}

        <div class="reviewable-filters-actions">
          <DButton
            @icon="arrows-rotate"
            @label="review.filters.refresh"
            @action={{@controller.refresh}}
            class="btn-primary refresh"
          />

          {{#if @controller.site.mobileView}}
            <DButton
              @label="show_help"
              @icon={{@controller.toggleFiltersIcon}}
              @action={{@controller.toggleFilters}}
              class="btn-default expand-secondary-filters"
            />
          {{/if}}
        </div>
      </div>
    </div>
  </template>
);
