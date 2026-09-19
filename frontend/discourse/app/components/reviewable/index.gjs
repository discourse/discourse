import ReviewFilters from "discourse/components/review-filters";
import ReviewableItem from "discourse/components/reviewable/item";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DLoadMore from "discourse/ui-kit/d-load-more";
import { i18n } from "discourse-i18n";

const ReviewableIndex = <template>
  <div class="reviewable-container">
    <ReviewFilters @controller={{@controller}} />
    <div class="reviewable-list">
      {{#if @controller.reviewables.content}}
        <DLoadMore @action={{@controller.loadMore}}>
          <div class="reviewables">
            {{#each @controller.reviewables.content as |r|}}
              <ReviewableItem
                @reviewable={{r}}
                @showHelp={{false}}
                @updateStatuses={{@controller.updateStatuses}}
              />
            {{/each}}
          </div>
        </DLoadMore>
        <DConditionalLoadingSpinner
          @condition={{@controller.reviewables.loadingMore}}
        />
      {{else}}
        <div class="no-review">
          {{i18n "review.none"}}
        </div>
      {{/if}}
    </div>
  </div>
</template>;

export default ReviewableIndex;
