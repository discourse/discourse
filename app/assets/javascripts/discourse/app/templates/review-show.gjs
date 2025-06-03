import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { dasherize } from "@ember/string";
import RouteTemplate from "ember-route-template";
import { and } from "truth-helpers";
import ReviewableItem from "discourse/components/reviewable-item";
import ReviewableItemRefresh from "discourse/components/reviewable-refresh/item";

export default RouteTemplate(
  class extends Component {
    get refreshedReviewableComponentExists() {
      const owner = getOwner(this);
      const dasherized = dasherize(
        this.args.controller.reviewable.type
      ).replace("reviewable-", "reviewable-refresh/");

      return owner.hasRegistration(`component:${dasherized}`);
    }

    <template>
      {{#if
        (and
          @controller.siteSettings.reviewable_ui_refresh
          this.refreshedReviewableComponentExists
        )
      }}
        <ReviewableItemRefresh @reviewable={{@controller.reviewable}} />
      {{else}}
        <ReviewableItem @reviewable={{@controller.reviewable}} />
      {{/if}}
    </template>
  }
);
