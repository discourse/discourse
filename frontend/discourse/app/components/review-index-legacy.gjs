import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import LoadMore from "discourse/components/load-more";
import ReviewFilters from "discourse/components/review-filters";
import ReviewableItem from "discourse/components/reviewable-item";
import { i18n } from "discourse-i18n";

export default <template>
  <div class="reviewable-container">
    <ReviewFilters @controller={{@controller}} />
    <div class="reviewable-list">
      {{#if @controller.reviewables.content}}
        <LoadMore @action={{@controller.loadMore}}>
          <div class="reviewables">
            {{#each @controller.reviewables.content as |r|}}
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
  </div>
</template>
