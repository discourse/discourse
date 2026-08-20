import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import PostLikedUsersMenu from "./liked-users-menu";

const MENU_IDENTIFIER = "post-liked-users-menu";

export default class LikedUsersList extends Component {
  @service menu;

  get buttonIcon() {
    return this.args.post.yours ? "d-liked" : null;
  }

  get elementId() {
    return `post-liked-users-list-${this.args.post.id}`;
  }

  get expanded() {
    return this.menu.getByIdentifier(MENU_IDENTIFIER)?.id === this.elementId;
  }

  @action
  togglePopup(event) {
    this.menu.show(event.currentTarget, {
      identifier: MENU_IDENTIFIER,
      component: PostLikedUsersMenu,
      modalForMobile: true,
      closeOnScroll: true,
      arrow: true,
      placement: "bottom",
      offset: 15,
      data: { post: this.args.post },
    });
  }

  <template>
    <button
      id={{this.elementId}}
      type="button"
      aria-label={{i18n "post.sr_post_like_count_button" count=@post.likeCount}}
      aria-haspopup="dialog"
      aria-expanded={{if this.expanded "true" "false"}}
      class={{dConcatClass
        "btn btn-flat no-text"
        "post-action-menu__like-count"
        "like-count"
        "button-count"
        "highlight-action"
        (if @post.liked "has-liked")
        (if @post.yours "my-likes" "regular-likes")
      }}
      {{on "click" this.togglePopup}}
      ...attributes
    >
      {{#if this.buttonIcon}}
        {{dIcon this.buttonIcon}}
      {{/if}}
      {{@post.likeCount}}
    </button>
  </template>
}
