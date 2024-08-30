import Component from "@glimmer/component";
import { action } from "@ember/object";
import { gt } from "truth-helpers";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import DiscourseURL from "discourse/lib/url";

export default class PostMenuFlagButton extends Component {
  get shouldRender() {
    const { reviewableId, canFlag, hidden } = this.args.transformedPost;
    return reviewableId || (canFlag && !hidden);
  }

  @action
  navigateToReviewable() {
    DiscourseURL.routeTo(`/review/${this.args.transformedPost.reviewableId}`);
  }

  <template>
    {{#if this.shouldRender}}
      <div class="double-button">
        {{#if @transformedPost.reviewableId}}
          <DButton
            class={{concatClass
              "button-count"
              (if
                (gt @transformedPost.reviewableScorePendingCount 0)
                "has-pending"
              )
            }}
            ...attributes
            @action={{this.navigateToReviewable}}
          >
            <span>{{@transformedPost.reviewableScoreCount}}</span>
          </DButton>
        {{/if}}
        <DButton
          class="create-flag"
          ...attributes
          @icon="flag"
          @title="post.controls.flag"
          @action={{@action}}
        />
      </div>
    {{/if}}
  </template>
}
