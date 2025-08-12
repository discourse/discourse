import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import avatar from "discourse/helpers/bound-avatar-template";
import concatClass from "discourse/helpers/concat-class";
import discourseLater from "discourse/lib/later";
import { applyValueTransformer } from "discourse/lib/transformer";
import LikedUsersList from "./liked-users-list";

export default class PostMenuLikeButton extends Component {
  static shouldRender(args) {
    const show = args.post.showLike || args.post.likeCount > 0;
    return applyValueTransformer("like-button-render-decision", show, {
      post: args.post,
    });
  }

  @service currentUser;
  @service store;

  @tracked isAnimated = false;
  @tracked likedUsers = null;
  @tracked totalLikedUsers = 0;
  @tracked loadingLikedUsers = false;

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

  @action
  async fetchLikedUsers() {
    if (this.likedUsers || this.loadingLikedUsers) {
      return;
    }

    this.loadingLikedUsers = true;

    try {
      const users = await this.store.find("post-action-user", {
        id: this.args.post.id,
        post_action_type_id: 2, // LIKE_ACTION
      });

      this.likedUsers = users.map((user) => ({
        id: user.id,
        username: user.username,
        name: user.name,
        avatar_template: user.avatar_template,
      }));
      console.log(this.likedUsers);

      this.totalLikedUsers = users.totalRows;
    } catch {
      // Silently handle error - could add user notification here if needed
    } finally {
      this.loadingLikedUsers = false;
    }
  }

  <template>
    {{#if @post.showLike}}
      <div class="double-button">
        {{#if @post.likeCount}}
          <LikedUsersList ...attributes @post={{@post}} />
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
        <LikedUsersList ...attributes @post={{@post}} />
      </div>
    {{/if}}
  </template>
}
