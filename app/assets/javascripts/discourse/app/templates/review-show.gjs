import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { dasherize } from "@ember/string";
import RouteTemplate from "ember-route-template";
import ReviewableItem from "discourse/components/reviewable-item";
import ReviewableItemRefresh from "discourse/components/reviewable-refresh/item";

export default RouteTemplate(
  class extends Component {
    @service currentUser;
    @service site;

    /**
     * Checks if a refreshed reviewable component exists for the current reviewable type.
     *
     * @returns {boolean} True if the refreshed component exists, false otherwise
     */
    get refreshedReviewableComponentExists() {
      const owner = getOwner(this);
      const dasherized = dasherize(
        this.args.controller.reviewable.type
      ).replace("reviewable-", "reviewable-refresh/");

      return owner.hasRegistration(`component:${dasherized}`);
    }

    /**
     * Determines if the current user can use the refreshed reviewable UI.
     *
     * @returns {boolean} True if the current user can access the refreshed UI, false otherwise
     */
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

    /**
     * Determines whether to use the refreshed reviewable UI component.
     *
     * @returns {boolean} True if both conditions are met: user has permission and component exists
     */
    get shouldUseRefreshUI() {
      return this.canUseRefreshUI && this.refreshedReviewableComponentExists;
    }

    <template>
      {{#if this.shouldUseRefreshUI}}
        <ReviewableItemRefresh @reviewable={{@controller.reviewable}} />
      {{else}}
        <ReviewableItem @reviewable={{@controller.reviewable}} />
      {{/if}}
    </template>
  }
);
