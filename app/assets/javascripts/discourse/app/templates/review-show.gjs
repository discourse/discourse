import Component from "@glimmer/component";
import { service } from "@ember/service";
import RouteTemplate from "ember-route-template";
import ReviewableItem from "discourse/components/reviewable-item";
import ReviewableItemRefresh from "discourse/components/reviewable-refresh/item";

export default RouteTemplate(
  class extends Component {
    @service currentUser;
    @service site;

    /**
     * Determines whether to use the refreshed reviewable UI component.
     *
     * @returns {boolean} True if both conditions are met: user has permission and component exists
     */
    get shouldUseRefreshUI() {
      return this.currentUser.use_reviewable_ui_refresh;
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
