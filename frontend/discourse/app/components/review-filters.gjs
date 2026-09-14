import { fn, hash } from "@ember/helper";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import CategoryChooser from "discourse/select-kit/components/category-chooser";
import ComboBox from "discourse/select-kit/components/combo-box";
import EmailGroupUserChooser from "discourse/select-kit/components/email-group-user-chooser";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DDateTimeInputRange from "discourse/ui-kit/d-date-time-input-range";
import { i18n } from "discourse-i18n";

export default <template>
  <div
    class="reviewable-filters
      {{if @controller.filtersExpanded '--expanded' '--collapsed'}}"
  >
    <div class="reviewable-filter">
      <label class="filter-label">
        {{i18n "review.filters.status"}}
      </label>
      <ComboBox
        @content={{@controller.statuses}}
        @onChange={{fn (mut @controller.filterStatus)}}
        @value={{@controller.filterStatus}}
      />
    </div>

    <div class="reviewable-filter">
      <label class="filter-label">
        {{i18n "review.filters.type.title"}}
      </label>
      <ComboBox
        @content={{@controller.allTypes}}
        @onChange={{fn (mut @controller.filterType)}}
        @options={{hash none="review.filters.type.all"}}
        @value={{@controller.filterType}}
      />
    </div>

    {{#if @controller.filtersExpanded}}

      <PluginOutlet
        @connectorTagName="div"
        @name="above-review-filters"
        @outletArgs={{lazyHash
          model=@controller.model
          additionalFilters=@controller.additionalFilters
        }}
      />

      {{#unless (eq @controller.siteSettings.reviewable_claiming "disabled")}}
        <div class="reviewable-filter topic-filter claimed-by">
          <label class="filter-label">
            {{i18n "review.filtered_claimed_by"}}
          </label>
          <EmailGroupUserChooser
            @onChange={{@controller.updateFilterClaimedBy}}
            @options={{hash
              maximum=1
              excludeCurrentUser=false
              fullWidthWrap=true
              customSearchOptions=(hash canReview=true)
            }}
            @value={{@controller.filterClaimedBy}}
          />
        </div>
      {{/unless}}

      <div class="reviewable-filter">
        <label class="filter-label">
          {{i18n "review.filters.score_type.title"}}
        </label>
        <ComboBox
          @content={{@controller.allScoreTypes}}
          @onChange={{fn (mut @controller.filterScoreType)}}
          @options={{hash none="review.filters.score_type.all"}}
          @value={{@controller.filterScoreType}}
        />
      </div>

      <div class="reviewable-filter">
        <label class="filter-label">
          {{i18n "review.filters.priority.title"}}
        </label>
        <ComboBox
          @content={{@controller.priorities}}
          @onChange={{fn (mut @controller.filterPriority)}}
          @value={{@controller.filterPriority}}
        />
      </div>

      <div class="reviewable-filter">
        <label class="filter-label">
          {{i18n "review.filters.category"}}
        </label>
        <CategoryChooser
          @onChange={{fn (mut @controller.filterCategoryId)}}
          @options={{hash none="review.filters.all_categories" clearable=true}}
          @value={{@controller.filterCategoryId}}
        />
      </div>

      <div class="reviewable-filter topic-filter">
        <label class="filter-label">
          {{i18n "review.filtered_flagged_by"}}
        </label>
        <EmailGroupUserChooser
          @onChange={{@controller.updateFilterFlaggedBy}}
          @options={{hash
            maximum=1
            excludeCurrentUser=false
            fullWidthWrap=true
          }}
          @value={{@controller.filterFlaggedBy}}
        />
      </div>

      <div class="reviewable-filter topic-filter">
        <label class="filter-label">
          {{i18n "review.filtered_reviewed_by"}}
        </label>
        <EmailGroupUserChooser
          @onChange={{@controller.updateFilterReviewedBy}}
          @options={{hash
            maximum=1
            excludeCurrentUser=false
            fullWidthWrap=true
          }}
          @value={{@controller.filterReviewedBy}}
        />
      </div>

      <div class="reviewable-filter topic-filter">
        <label class="filter-label">
          {{i18n "review.filtered_user"}}
        </label>
        <EmailGroupUserChooser
          class="user-selector"
          @onChange={{@controller.updateFilterUsername}}
          @options={{hash
            maximum=1
            excludeCurrentUser=false
            fullWidthWrap=true
          }}
          @value={{@controller.filterUsername}}
        />
      </div>

      {{#if @controller.filterTopic}}
        <div class="reviewable-filter topic-filter">
          <label class="filter-label">
            {{i18n "review.filtered_topic"}}
          </label>
          <DButton
            class="btn-default"
            @action={{@controller.resetTopic}}
            @icon="xmark"
            @label="review.show_all_topics"
          />
        </div>
      {{/if}}

      <div class="reviewable-filter sort-order">
        <label class="filter-label">
          {{i18n "review.order_by"}}
        </label>
        <ComboBox
          @content={{@controller.sortOrders}}
          @onChange={{fn (mut @controller.filterSortOrder)}}
          @value={{@controller.filterSortOrder}}
        />
      </div>

      <div class="reviewable-filter date-range">
        <label class="filter-label">
          {{i18n "review.date_filter"}}
        </label>
        <DDateTimeInputRange
          @from={{@controller.filterFromDate}}
          @onChange={{@controller.setRange}}
          @showFromTime={{false}}
          @showToTime={{false}}
          @to={{@controller.filterToDate}}
        />
      </div>
    {{/if}}

    <div class="reviewable-filters-actions">
      <DButton
        class="btn-primary refresh"
        @action={{@controller.refresh}}
        @icon="arrows-rotate"
        @label="review.filters.refresh"
      />

      <DButton
        class="btn-default expand-secondary-filters"
        @action={{@controller.toggleFilters}}
        @icon={{@controller.toggleFiltersIcon}}
        @label="show_help"
      />

    </div>
  </div>
</template>
