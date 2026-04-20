import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import UserAvatar from "discourse/components/user-avatar";
import UserLink from "discourse/components/user-link";
import icon from "discourse/helpers/d-icon";

const PAGE_SIZE = 30;

export default class PostUsersMenu extends Component {
  @service siteSettings;
  @service site;

  @tracked users = [];
  @tracked loading = false;
  @tracked canLoadMore = true;

  displayName = (user) => {
    if (user.name && !this.siteSettings.prioritize_username_in_ux) {
      return user.name;
    }
    return user.username;
  };

  resetAndReload = () => {
    this.users = [];
    this.#page = 0;
    this.canLoadMore = true;
    return this.#loadMore();
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

  <template>
    <div class="post-users-popup">
      {{#if this.site.mobileView}}
        <div class="post-users-popup__title">{{@titleText}}</div>
      {{/if}}

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
                {{this.displayName user}}
              </UserLink>
              {{#unless this.siteSettings.prioritize_username_in_ux}}
                <UserLink
                  @username={{user.username}}
                  class="post-users-popup__username"
                >
                  @{{user.username}}
                </UserLink>
              {{/unless}}
            </div>
            {{#if (has-block "reaction")}}
              {{yield user to="reaction"}}
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
