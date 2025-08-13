import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import discourseLater from "discourse/lib/later";
import { applyValueTransformer } from "discourse/lib/transformer";
import LikeCount from "./like-count";
import LikedUsersList from "./liked-users-list";

export default class PostMenuLikeButton extends Component {
  static shouldRender(args) {
    const show = args.post.showLike || args.post.likeCount > 0;
    return applyValueTransformer("like-button-render-decision", show, {
      post: args.post,
    });
  }

  @service currentUser;

  @tracked isAnimated = false;

  get disabled() {
    return this.currentUser && !this.args.post.canToggleLike;
  }

  get title() {
    // If the user has already liked the post and doesn't have permission
    // to undo that operation, then indicate via the title that they've liked it
    // and disable the button. Otherwise, set the title even if the user
    // is anonymous (meaning they don't currently have permission to like);
    // this is important for accessibility.

    if (this.args.post.liked && !this.args.post.canToggleLike) {
      return "post.controls.has_liked";
    }

    return this.args.post.liked
      ? "post.controls.undo_like"
      : "post.controls.like";
  }

  @action
  async toggleLike() {
    this.isAnimated = true;

    return new Promise((resolve) => {
      discourseLater(async () => {
        this.isAnimated = false;
        await this.args.buttonActions.toggleLike();
        resolve();
      }, 400);
    });
  }

  <template>
    {{#if @post.showLike}}
      <div class="double-button">
        {{#if @post.likeCount}}
          <LikedUsersList ...attributes @post={{@post}} />
        {{else}}
          <LikeCount
            ...attributes
            @action={{@buttonActions.toggleWhoLiked}}
            @state={{@state}}
            @post={{@post}}
          />
        {{/if}}
        <DButton
          class={{concatClass
            "post-action-menu__like"
            "toggle-like"
            "btn-icon"
            (if this.isAnimated "heart-animation")
            (if @post.liked "has-like" "like")
          }}
          ...attributes
          data-post-id={{@post.id}}
          disabled={{this.disabled}}
          @action={{this.toggleLike}}
          @icon={{if @post.liked "d-liked" "d-unliked"}}
          @label={{if @showLabel "post.controls.like_action"}}
          @title={{this.title}}
        />
      </div>
    {{else}}
      <div class="double-button">
        {{#if @post.likeCount}}
          <LikedUsersList ...attributes @post={{@post}} />
        {{else}}
          <LikeCount
            ...attributes
            @action={{@buttonActions.toggleWhoLiked}}
            @state={{@state}}
            @post={{@post}}
          />
        {{/if}}
      </div>
    {{/if}}
  </template>
}
