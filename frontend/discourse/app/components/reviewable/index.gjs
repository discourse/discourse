import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { dasherize } from "@ember/string";
import ReviewFilters from "discourse/components/review-filters";
import ReviewableItem from "discourse/components/reviewable/item";
import { bind } from "discourse/lib/decorators";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DLoadMore from "discourse/ui-kit/d-load-more";
import { i18n } from "discourse-i18n";

export default class ReviewIndexRefresh extends Component {
  @bind
  reviewableComponentExists(reviewable) {
    const owner = getOwner(this);
    // TODO plugins are still using `reviewable-refresh/` path. Once they are fixed, it can be remove.
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
          <DLoadMore @action={{@controller.loadMore}}>
            <div class="reviewables">
              {{#each @controller.reviewables.content as |r|}}
                {{#if (this.reviewableComponentExists r)}}
                  <ReviewableItem @reviewable={{r}} @showHelp={{false}} />
                {{/if}}
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
  </template>
}
