import Component from "@glimmer/component";
import { action } from "@ember/object";
import { gt } from "truth-helpers";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import { applyValueTransformer } from "discourse/lib/transformer";
import DiscourseURL from "discourse/lib/url";


export default class PostMenuFlagButton extends Component {
  static shouldRender(args, helper) {
    const { post } = args;
    const { reviewable_id, canFlag, hidden } = post;
    const siteSettings = helper.siteSettings;
    const currentUser = helper.currentUser;

    let show = false;
    if (siteSettings && currentUser) { // Ensure services are available
      if (reviewable_id && siteSettings.reviewable_claiming_enabled) {
        show = true;
      } else if (canFlag && !hidden) {
        show = true;
      }
    }

    // Allow plugins to modify this decision
    return applyValueTransformer(
      "flag-button-render-decision",
      show,
      { post, componentContext: helper } // Pass post and component instance as context
    );
  }

  get dynamicFlagButtonClass() {
    // Provide an empty string as the default class, and pass post and component instance as context
    return applyValueTransformer(
      "flag-button-dynamic-class",
      "",
      { post: this.args.post, componentContext: this }
    );
  }

  get isFlagButtonDisabled() {
    // Default to false (enabled), allow plugin to override
    return applyValueTransformer(
      "flag-button-disabled-state",
      false,
      { post: this.args.post, componentContext: this }
    );
  }

  get title() {
    return this.args.post.currentUser
      ? "post.controls.flag"
      : "post.controls.anonymous_flag";
  }

  @action
  navigateToReviewable() {
    DiscourseURL.routeTo(`/review/${this.args.post.reviewable_id}`);
  }

  <template>
    <div class="double-button">
      {{#if @post.reviewable_id}}
        <DButton
          class={{concatClass
            "button-count"
            (if (gt @post.reviewable_score_pending_count 0) "has-pending")
          }}
          ...attributes
          @action={{this.navigateToReviewable}}
        >
          <span>{{@post.reviewable_score_count}}</span>
        </DButton>
      {{/if}}
      <DButton
        class={{concatClass "post-action-menu__flag create-flag" this.dynamicFlagButtonClass}}
        ...attributes
        @action={{@buttonActions.showFlags}}
        @icon="flag"
        @label={{if @showLabel "post.controls.flag_action"}}
        @title={{this.title}}
        @disabled={{this.isFlagButtonDisabled}}
      />
    </div>
  </template>
}
