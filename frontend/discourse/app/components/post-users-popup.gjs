import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { schedule } from "@ember/runloop";
import { computePosition, flip, offset, shift } from "@floating-ui/dom";
import UserAvatar from "discourse/components/user-avatar";
import UserLink from "discourse/components/user-link";
import icon from "discourse/helpers/d-icon";
import emoji from "discourse/helpers/emoji";

const PAGE_SIZE = 30;

export default class PostUsersPopup extends Component {
  @tracked users = [];
  @tracked loading = false;
  @tracked canLoadMore = true;

  resetAndReload = () => {
    this.users = [];
    this.#page = 0;
    this.canLoadMore = true;
    this.#loadMore();
  };
  #page = 0;

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
    if (event.target.closest("[data-user-card]")) {
      return;
    }
    event.stopPropagation();
  }

  @action
  didInsertPopup(element) {
    this.#positionPopup(element);
  }

  async #loadMore() {
    if (this.loading || !this.canLoadMore) {
      return;
    }

    this.loading = true;

    try {
      const { users, canLoadMore } = await this.args.fetchUsers(
        this.#page,
        PAGE_SIZE
      );

      this.users = [...this.users, ...users];
      this.#page++;
      this.canLoadMore = canLoadMore;
    } finally {
      this.loading = false;
    }
  }

  #positionPopup(popupEl) {
    schedule("afterRender", () => {
      const referenceEl = this.args.referenceElement;
      const arrowEl = popupEl?.querySelector(".post-users-popup__arrow");

      if (!referenceEl || !popupEl) {
        return;
      }

      computePosition(referenceEl, popupEl, {
        strategy: "fixed",
        placement: "bottom",
        middleware: [offset(18), flip({ padding: 10 }), shift({ padding: 10 })],
      }).then(({ x, y }) => {
        Object.assign(popupEl.style, {
          left: `${x}px`,
          top: `${y}px`,
        });

        if (arrowEl) {
          const refRect = referenceEl.getBoundingClientRect();
          const popupRect = popupEl.getBoundingClientRect();
          const arrowX = refRect.left + refRect.width / 2 - popupRect.left;
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
      class="post-users-popup"
      {{on "click" this.preventClose}}
      {{on "mousedown" this.preventClose}}
      {{on "mouseup" this.preventClose}}
      {{didInsert this.didInsertPopup}}
    >
      <div class="post-users-popup__arrow"></div>
      {{yield this.resetAndReload to="header"}}
      <div
        class="post-users-popup__body"
        {{on "scroll" this.onScroll}}
        {{didInsert this.loadInitial}}
      >
        {{#each this.users as |user|}}
          <div class="post-users-popup__item">
            <UserLink
              @username={{user.username}}
              class="post-users-popup__avatar-link"
            >
              <UserAvatar @user={{user}} @size="small" />
            </UserLink>
            <div class="post-users-popup__user-info">
              <UserLink
                @username={{user.username}}
                class="post-users-popup__name"
              >
                {{if user.name user.name user.username}}
              </UserLink>
              {{#if user.name}}
                <span class="post-users-popup__username">
                  @{{user.username}}
                </span>
              {{/if}}
            </div>
            {{#if user.reaction}}
              {{emoji
                user.reaction
                skipTitle=true
                class="post-users-popup__reaction"
              }}
            {{else}}
              {{icon "d-liked" class="post-users-popup__reaction"}}
            {{/if}}
          </div>
        {{/each}}
        {{#if this.loading}}
          <div class="post-users-popup__loading">
            <div class="spinner small"></div>
          </div>
        {{/if}}
      </div>
    </div>
  </template>
}
