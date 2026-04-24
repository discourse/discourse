import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import LoadMore from "discourse/components/load-more";
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
  @tracked bodyMinHeight = null;

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

  get bodyStyle() {
    if (this.bodyMinHeight) {
      return trustHTML(`min-height: ${this.bodyMinHeight}px`);
    }
    return null;
  }

  @action
  async loadInitial(element) {
    await this.#loadMore();
    if (this.site.mobileView) {
      return;
    }
    schedule("afterRender", () => {
      this.bodyMinHeight = element.offsetHeight;
    });
  }

  @action
  loadMore() {
    return this.#loadMore();
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
      <div class="post-users-popup__sticky-header">
        {{#if this.site.mobileView}}
          <div class="post-users-popup__title">{{@titleText}}</div>
        {{/if}}

        {{yield this.resetAndReload to="header"}}
      </div>

      <div
        class="post-users-popup__body"
        style={{this.bodyStyle}}
        {{didInsert this.loadInitial}}
      >
        <LoadMore
          @action={{this.loadMore}}
          @enabled={{this.canLoadMore}}
          @isLoading={{this.loading}}
          @rootMargin="100px"
        >
          {{#each this.users as |user|}}
            <div class="post-users-popup__item">
              {{#if (has-block "avatar")}}
                {{yield user to="avatar"}}
              {{else}}
                <UserAvatar @user={{user}} @size="small" />
              {{/if}}
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
          <ConditionalLoadingSpinner
            @condition={{this.loading}}
            @size="small"
          />
        </LoadMore>
      </div>
    </div>
  </template>
}
