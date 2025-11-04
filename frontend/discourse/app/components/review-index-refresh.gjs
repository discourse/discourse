import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { dasherize } from "@ember/string";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import LoadMore from "discourse/components/load-more";
import ReviewFilters from "discourse/components/review-filters";
import ReviewableItem from "discourse/components/reviewable-item";
import ReviewableItemRefresh from "discourse/components/reviewable-refresh/item";
import { bind } from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";

export default class ReviewIndexRefresh extends Component {
  @service currentUser;

  @bind
  refreshedReviewableComponentExists(reviewable) {
    const owner = getOwner(this);
    const dasherized = dasherize(reviewable.type).replace(
      "reviewable-",
      "reviewable-refresh/"
    );
    return owner.hasRegistration(`component:${dasherized}`);
  }

  @bind
  shouldUseRefreshUI(reviewable) {
    return (
      this.currentUser.use_reviewable_ui_refresh &&
      this.refreshedReviewableComponentExists(reviewable)
    );
  }

  <template>
    <div class="reviewable-container">
      <ReviewFilters @controller={{@controller}} />
      <div class="reviewable-list">
        {{#if @controller.reviewables.content}}
          <LoadMore
            @action={{@controller.loadMore}}
            @rootMargin="0px 0px 200px 0px"
          >
            <div class="reviewables">
              {{#each @controller.reviewables.content as |r|}}
                {{#if (this.shouldUseRefreshUI r)}}
                  <ReviewableItemRefresh
                    @reviewable={{r}}
                    @showHelp={{false}}
                  />
                {{else}}
                  <ReviewableItem
                    @reviewable={{r}}
                    @remove={{@controller.remove}}
                  />
                {{/if}}
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
}
