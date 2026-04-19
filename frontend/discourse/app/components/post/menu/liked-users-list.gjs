import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import PostUsersPopup from "discourse/components/post-users-popup";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import closeOnClickOutside from "discourse/modifiers/close-on-click-outside";
import { i18n } from "discourse-i18n";

const LIKE_ACTION = 2;

export default class LikedUsersList extends Component {
  @tracked popupExpanded = false;

  fetchUsers = async (page, pageSize) => {
    const result = await ajax("/post_action_users", {
      data: {
        id: this.args.post.id,
        post_action_type_id: LIKE_ACTION,
        page,
        limit: pageSize,
      },
    });

    const newUsers = result.post_action_users || [];
    let canLoadMore;

    if (newUsers.length < pageSize) {
      canLoadMore = false;
    } else if (result.total_rows_post_action_users) {
      canLoadMore = true;
    } else {
      canLoadMore = false;
    }

    return { users: newUsers, canLoadMore };
  };
  #scrollHandler = null;

  get buttonIcon() {
    if (!this.args.post.showLike) {
      return this.args.post.yours ? "d-liked" : "d-unliked";
    }

    if (this.args.post.yours) {
      return "d-liked";
    }
  }

  get elementId() {
    return `post-like-users_${this.args.post.id}`;
  }

  get referenceElement() {
    return document.getElementById(this.elementId);
  }

  @action
  togglePopup() {
    if (this.popupExpanded) {
      this.#closePopup();
    } else {
      this.popupExpanded = true;
      this.#scrollHandler = () => this.#closePopup();
      window.addEventListener("scroll", this.#scrollHandler, {
        once: true,
        passive: true,
      });
    }
  }

  @action
  clickOutside() {
    if (this.popupExpanded) {
      this.#closePopup();
    }
  }

  @action
  keyDown(event) {
    if (event.key === "Escape" && this.popupExpanded) {
      event.stopPropagation();
      this.#closePopup();
    }
  }

  #closePopup() {
    this.popupExpanded = false;
    if (this.#scrollHandler) {
      window.removeEventListener("scroll", this.#scrollHandler);
      this.#scrollHandler = null;
    }
  }

  <template>
    {{! template-lint-disable no-invalid-interactive }}
    <div
      id={{this.elementId}}
      class="post-likes-popup-wrapper"
      {{closeOnClickOutside this.clickOutside}}
      {{on "keydown" this.keyDown}}
    >
      <button
        type="button"
        aria-label={{i18n
          "post.sr_post_like_count_button"
          count=@post.likeCount
        }}
        class={{concatClass
          "btn btn-flat no-text"
          "post-action-menu__like-count"
          "like-count"
          "button-count"
          "highlight-action"
          (if @post.yours "my-likes" "regular-likes")
        }}
        {{on "click" this.togglePopup}}
        ...attributes
      >
        {{#if this.buttonIcon}}
          {{icon this.buttonIcon}}
        {{/if}}
        {{@post.likeCount}}
      </button>

      {{#if this.popupExpanded}}
        <PostUsersPopup
          @referenceElement={{this.referenceElement}}
          @fetchUsers={{this.fetchUsers}}
        />
      {{/if}}
    </div>
  </template>
}
