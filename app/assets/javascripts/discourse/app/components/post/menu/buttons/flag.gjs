import Component from "@glimmer/component";
import { action } from "@ember/object";
import { gt } from "truth-helpers";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import DiscourseURL from "discourse/lib/url";

export default class PostMenuFlagButton extends Component {
  static shouldRender(post) {
    const { reviewable_id, canFlag, hidden } = post;
    return reviewable_id || (canFlag && !hidden);
  }

  @action
  navigateToReviewable() {
    DiscourseURL.routeTo(`/review/${this.args.post.reviewable_id}`);
  }

  <template>
    {{#if @shouldRender}}
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
          class="create-flag"
          ...attributes
          @action={{@action}}
          @icon="flag"
          @label={{if @showLabel "post.controls.flag_action"}}
          @title="post.controls.flag"
        />
      </div>
    {{/if}}
  </template>
}
