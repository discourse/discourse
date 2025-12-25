import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { LinkTo } from "@ember/routing";
import { dasherize } from "@ember/string";
import ReviewableItemRefresh from "discourse/components/reviewable-refresh/item";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class extends Component {
  /**
   * Checks if a refreshed reviewable component exists for the current reviewable type.
   *
   * @returns {boolean} True if the refreshed component exists, false otherwise
   */
  get refreshedReviewableComponentExists() {
    const owner = getOwner(this);
    const dasherized = dasherize(this.args.controller.reviewable.type).replace(
      "reviewable-",
      "reviewable-refresh/"
    );

    return owner.hasRegistration(`component:${dasherized}`);
  }

  <template>
    {{#if this.refreshedReviewableComponentExists}}
      <div class="reviewable-top-nav">
        <LinkTo @route="review.index">
          {{icon "arrow-left"}}
          {{i18n "review.back_to_queue"}}
        </LinkTo>
      </div>
      <ReviewableItemRefresh
        @reviewable={{@controller.reviewable}}
        @showHelp={{true}}
      />
    {{/if}}
  </template>
}
