import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import UserAvatar from "discourse/components/user-avatar";
import UserLink from "discourse/components/user-link";
import icon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";

const LIKE_ACTION = 2;
const PAGE_SIZE = 30;

export default class PostLikedUsersMenu extends Component {
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
  #page = 0;

  get post() {
    return this.args.data.post;
  }

  get titleText() {
    return i18n("post.likes_popup.title", {
      count: this.post.likeCount,
    });
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

  async #loadMore() {
    if (this.loading || !this.canLoadMore) {
      return;
    }

    this.loading = true;

    try {
      const result = await ajax("/post_action_users", {
        data: {
          id: this.post.id,
          post_action_type_id: LIKE_ACTION,
          page: this.#page,
          limit: PAGE_SIZE,
        },
      });

      const newUsers = result.post_action_users ?? [];
      this.users = [...this.users, ...newUsers];
      this.#page++;

      if (newUsers.length < PAGE_SIZE) {
        this.canLoadMore = false;
      } else {
        this.canLoadMore = !!result.total_rows_post_action_users;
      }
    } finally {
      this.loading = false;
    }
  }

  <template>
    <div class="post-users-popup">
      {{#if this.site.mobileView}}
        <div class="post-users-popup__title">{{this.titleText}}</div>
      {{/if}}

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
            {{icon "d-liked" class="post-users-popup__reaction"}}
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
