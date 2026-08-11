import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { LinkTo } from "@ember/routing";
import ReviewableItem from "discourse/components/reviewable/item";
import { reviewableComponentExists } from "discourse/lib/reviewable-registry";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class extends Component {
  get reviewableComponentExists() {
    return reviewableComponentExists(
      getOwner(this),
      this.args.controller.reviewable.type
    );
  }

  <template>
    {{#if this.reviewableComponentExists}}
      <div class="reviewable-top-nav">
        <LinkTo @route="review.index">
          {{dIcon "arrow-left"}}
          {{i18n "review.back_to_queue"}}
        </LinkTo>
      </div>
      <ReviewableItem
        @reviewable={{@controller.reviewable}}
        @showHelp={{true}}
      />
    {{/if}}
  </template>
}
