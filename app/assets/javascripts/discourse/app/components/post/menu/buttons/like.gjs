import Component from "@glimmer/component";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { inject as service } from "@ember/service";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import i18n from "discourse-common/helpers/i18n";
import { bind } from "discourse-common/utils/decorators";

export default class PostMenuLikeButton extends Component {
  static shouldRender(post) {
    return post.showLike;
  }

  @service currentUser;

  #element;

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

  @bind
  setElement(element) {
    this.#element = element;
  }

  @action
  animateToggle() {
    this.#element.classList.add("has-like");
    const icon = this.#element.querySelector(`.d-icon`);
    icon.classList.add("heart-animation");
  }

  <template>
    {{#if @shouldRender}}
      <div class="double-button">
        <LikeCount ...attributes @post={{@post}} @action={{@secondaryAction}} />
        <DButton
          class={{concatClass
            "toggle-like"
            (if @post.liked "has-like fade-out" "like")
          }}
          ...attributes
          data-post-id={{@post.id}}
          disabled={{this.disabled}}
          @action={{fn @action (hash onBeforeToggle=this.animateToggle)}}
          @icon={{if @post.liked "d-liked" "d-unliked"}}
          @label={{if @showLabel "post.controls.like_action"}}
          @title={{this.title}}
          {{didInsert this.setElement}}
        />
      </div>
    {{else if @post.likeCount}}
      <div class="double-button">
        <LikeCount ...attributes @post={{@post}} @action={{@secondaryAction}} />
      </div>
    {{/if}}
  </template>
}

class LikeCount extends Component {
  get icon() {
    if (!this.args.post.showLike) {
      return this.args.post.yours ? "d-liked" : "d-unliked";
    }

    if (this.args.post.yours) {
      return "d-liked";
    }
  }

  get translatedTitle() {
    let title;

    if (this.args.post.liked) {
      title =
        this.args.post.likeCount === 1
          ? "post.has_likes_title_only_you"
          : "post.has_likes_title_you";
    } else {
      title = "post.has_likes_title";
    }

    return i18n(title, {
      count: this.args.post.liked
        ? this.args.post.likeCount - 1
        : this.args.post.likeCount,
    });
  }

  <template>
    {{#if @post.likeCount}}
      <DButton
        class={{concatClass
          "button-count"
          "like-count"
          "highlight-action"
          (if @post.yours "my-likes" "regular-likes")
        }}
        ...attributes
        @ariaPressed={{@likedUsers}}
        @icon={{this.icon}}
        @translatedAriaLabel={{i18n
          "post.sr_post_like_count_button"
          count=@post.likeCount
        }}
        @translatedTitle={{this.translatedTitle}}
        @action={{@action}}
      >
        {{@post.likeCount}}
      </DButton>
    {{/if}}
  </template>
}
