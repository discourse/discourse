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

    let show =
      reviewable_id ||
      (canFlag && !hidden) ||
      (helper.siteSettings.allow_all_users_to_flag_illegal_content &&
        !helper.currentUser);

    return applyValueTransformer("flag-button-render-decision", show, { post });
  }

  get dynamicFlagButtonClass() {
    return applyValueTransformer("flag-button-dynamic-class", "", {
      post: this.args.post,
    });
  }

  get isFlagButtonDisabled() {
    return applyValueTransformer("flag-button-disabled-state", false, {
      post: this.args.post,
    });
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
        class={{concatClass
          "post-action-menu__flag create-flag"
          this.dynamicFlagButtonClass
        }}
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
