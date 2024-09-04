import Component from "@glimmer/component";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { inject as service } from "@ember/service";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import { bind } from "discourse-common/utils/decorators";
import LikeCount from "./like-count";

export default class PostMenuLikeButton extends Component {
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
    {{#if @post.showLike}}
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
          @icon={{if @post.liked "d-liked" "d-unliked"}}
          @title={{this.title}}
          @action={{fn @action (hash onBeforeToggle=this.animateToggle)}}
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
