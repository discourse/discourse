import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { dasherize } from "@ember/string";
import RouteTemplate from "ember-route-template";
import { and } from "truth-helpers";
import ReviewableItem from "discourse/components/reviewable-item";
import ReviewableItemRefresh from "discourse/components/reviewable-refresh/item";

export default RouteTemplate(
  class extends Component {
    @service currentUser;
    @service site;

    get refreshedReviewableComponentExists() {
      const owner = getOwner(this);
      const dasherized = dasherize(
        this.args.controller.reviewable.type
      ).replace("reviewable-", "reviewable-refresh/");

      return owner.hasRegistration(`component:${dasherized}`);
    }

    get canUseRefreshUI() {
      if (!this.currentUser) {
        return false;
      }

      const allowedGroupIds =
        this.args.controller.siteSettings.reviewable_ui_refresh;
      if (!allowedGroupIds) {
        return false;
      }

      // Convert comma-separated string to array of numbers
      const groupIds = allowedGroupIds
        .toString()
        .split(",")
        .map((id) => parseInt(id.trim(), 10))
        .filter((id) => !isNaN(id));

      // Check if current user is in any of the specified groups
      return this.currentUser.groups.some((userGroup) =>
        groupIds.includes(userGroup.id)
      );
    }

    <template>
      {{#if (and this.canUseRefreshUI this.refreshedReviewableComponentExists)}}
        <ReviewableItemRefresh @reviewable={{@controller.reviewable}} />
      {{else}}
        <ReviewableItem @reviewable={{@controller.reviewable}} />
      {{/if}}
    </template>
  }
);
