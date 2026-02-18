import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { LinkTo } from "@ember/routing";
import { dasherize } from "@ember/string";
import ReviewableItem from "discourse/components/reviewable/item";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class extends Component {
  // TODO plugins are still using `reviewable-refresh/` path. Once they are fixed, it can be remove.
  get reviewableComponentExists() {
    const owner = getOwner(this);
    let dasherized = dasherize(this.args.controller.reviewable.type).replace(
      "reviewable-",
      "reviewable-refresh/"
    );
    if (owner.hasRegistration(`component:${dasherized}`)) {
      return true;
    }

    dasherized = dasherize(this.args.controller.reviewable.type).replace(
      "reviewable-",
      "reviewable/"
    );
    return owner.hasRegistration(`component:${dasherized}`);
  }

  <template>
    {{#if this.reviewableComponentExists}}
      <div class="reviewable-top-nav">
        <LinkTo @route="review.index">
          {{icon "arrow-left"}}
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
