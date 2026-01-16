import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { dasherize } from "@ember/string";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import LoadMore from "discourse/components/load-more";
import ReviewFilters from "discourse/components/review-filters";
import ReviewableItem from "discourse/components/reviewable/item";
import { bind } from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";

export default class ReviewIndexRefresh extends Component {
  @bind
  refreshedReviewableComponentExists(reviewable) {
    const owner = getOwner(this);
    let dasherized = dasherize(reviewable.type).replace(
      "reviewable-",
      "reviewable-refresh/"
    );
    if (owner.hasRegistration(`component:${dasherized}`)) {
      return true;
    }

    dasherized = dasherize(reviewable.type).replace(
      "reviewable-",
      "reviewable/"
    );
    return owner.hasRegistration(`component:${dasherized}`);
  }

  <template>
    <div class="reviewable-container">
      <ReviewFilters @controller={{@controller}} />
      <div class="reviewable-list">
        {{#if @controller.reviewables.content}}
          <LoadMore @action={{@controller.loadMore}}>
            <div class="reviewables">
              {{#each @controller.reviewables.content as |r|}}
                {{#if (this.refreshedReviewableComponentExists r)}}
                  <ReviewableItem @reviewable={{r}} @showHelp={{false}} />
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
