import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { schedule } from "@ember/runloop";
import { computePosition, flip, offset, shift } from "@floating-ui/dom";
import UserAvatar from "discourse/components/user-avatar";
import UserLink from "discourse/components/user-link";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import closeOnClickOutside from "discourse/modifiers/close-on-click-outside";
import { i18n } from "discourse-i18n";

const PAGE_SIZE = 30;
const LIKE_ACTION = 2;

export default class LikedUsersList extends Component {
  @tracked popupExpanded = false;
  @tracked users = [];
  @tracked loading = false;
  @tracked canLoadMore = true;

  #page = 0;

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

  @action
  togglePopup() {
    if (this.popupExpanded) {
      this.#closePopup();
    } else {
      this.users = [];
      this.#page = 0;
      this.canLoadMore = true;
      this.popupExpanded = true;
      this.#positionPopup();
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

  #closePopup() {
    this.popupExpanded = false;
    if (this.#scrollHandler) {
      window.removeEventListener("scroll", this.#scrollHandler);
      this.#scrollHandler = null;
    }
  }

  @action
  keyDown(event) {
    if (event.key === "Escape" && this.popupExpanded) {
      event.stopPropagation();
      this.#closePopup();
    }
  }

  @action
  async loadInitial() {
    await this.#loadMore();
  }

  @action
  onScroll(event) {
    const el = event.target;
    if (el.scrollTop + el.clientHeight >= el.scrollHeight - 50) {
      this.#loadMore();
    }
  }

  @action
  preventClose(event) {
    event.stopPropagation();
  }

  async #loadMore() {
    if (this.loading || !this.canLoadMore) {
      return;
    }

    this.loading = true;

    try {
      const result = await ajax("/post_action_users", {
        data: {
          id: this.args.post.id,
          post_action_type_id: LIKE_ACTION,
          page: this.#page,
          limit: PAGE_SIZE,
        },
      });

      const newUsers = result.post_action_users || [];
      this.users = [...this.users, ...newUsers];
      this.#page++;

      if (newUsers.length < PAGE_SIZE) {
        this.canLoadMore = false;
      } else if (result.total_rows_post_action_users) {
        this.canLoadMore =
          this.users.length < result.total_rows_post_action_users;
      } else {
        this.canLoadMore = false;
      }
    } finally {
      this.loading = false;
    }
  }

  #positionPopup() {
    schedule("afterRender", () => {
      const container = document.getElementById(this.elementId);
      const popupEl = container?.querySelector(".post-likes-popup");
      const arrowEl = popupEl?.querySelector(".post-likes-popup__arrow");

      if (!container || !popupEl) {
        return;
      }

      computePosition(container, popupEl, {
        strategy: "fixed",
        placement: "bottom",
        middleware: [offset(18), flip({ padding: 10 }), shift({ padding: 10 })],
      }).then(({ x, y }) => {
        Object.assign(popupEl.style, {
          left: `${x}px`,
          top: `${y}px`,
        });

        if (arrowEl) {
          const containerRect = container.getBoundingClientRect();
          const popupRect = popupEl.getBoundingClientRect();
          const arrowX =
            containerRect.left + containerRect.width / 2 - popupRect.left;
          Object.assign(arrowEl.style, {
            left: `${arrowX}px`,
          });
        }
      });
    });
  }

  <template>
    {{! template-lint-disable no-invalid-interactive no-pointer-down-event-binding }}
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
      >
        {{#if this.buttonIcon}}
          {{icon this.buttonIcon}}
        {{/if}}
        {{@post.likeCount}}
      </button>

      {{#if this.popupExpanded}}
        <div
          class="post-likes-popup"
          {{on "click" this.preventClose}}
          {{on "mousedown" this.preventClose}}
          {{on "mouseup" this.preventClose}}
        >
          <div class="post-likes-popup__arrow"></div>
          <div
            class="post-likes-popup__body"
            {{on "scroll" this.onScroll}}
            {{didInsert this.loadInitial}}
          >
            {{#each this.users as |user|}}
              <div class="post-likes-popup__item">
                <UserLink
                  @username={{user.username}}
                  class="post-likes-popup__avatar-link"
                >
                  <UserAvatar @user={{user}} @size="small" />
                </UserLink>
                <div class="post-likes-popup__user-info">
                  <UserLink
                    @username={{user.username}}
                    class="post-likes-popup__name"
                  >
                    {{if user.name user.name user.username}}
                  </UserLink>
                  {{#if user.name}}
                    <span class="post-likes-popup__username">
                      @{{user.username}}
                    </span>
                  {{/if}}
                </div>
                {{icon "d-liked" class="post-likes-popup__reaction"}}
              </div>
            {{/each}}
            {{#if this.loading}}
              <div class="post-likes-popup__loading">
                <div class="spinner small"></div>
              </div>
            {{/if}}
          </div>
        </div>
      {{/if}}
    </div>
  </template>
}
