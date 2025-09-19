import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { dasherize } from "@ember/string";
import RouteTemplate from "ember-route-template";
import NavItem from "discourse/components/nav-item";
import ReviewableItem from "discourse/components/reviewable-item";
import ReviewableItemRefresh from "discourse/components/reviewable-refresh/item";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

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
     * Determines whether to use the refreshed reviewable UI component.
     *
     * @returns {boolean} True if both conditions are met: user has permission and component exists
     */
    get shouldUseRefreshUI() {
      return (
        this.currentUser.use_reviewable_ui_refresh &&
        this.refreshedReviewableComponentExists
      );
    }

    <template>
      {{#if this.shouldUseRefreshUI}}
        <div class="reviewable-top-nav">
          <LinkTo @route="review.index">
            {{icon "arrow-left"}}
            {{i18n "review.back_to_queue"}}
          </LinkTo>
        </div>
        <ReviewableItemRefresh @reviewable={{@controller.reviewable}} />
      {{else}}
        <ul class="nav nav-pills reviewable-title">
          <NavItem @route="review.index" @label="review.view_all" />
          <NavItem @route="review.topics" @label="review.grouped_by_topic" />
          {{#if @controller.currentUser.admin}}
            <NavItem
              @route="review.settings"
              @label="review.settings.title"
              @icon="wrench"
            />
          {{/if}}
        </ul>
        <ReviewableItem @reviewable={{@controller.reviewable}} />
      {{/if}}
    </template>
  }
);
