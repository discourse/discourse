import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { applyValueTransformer } from "discourse/lib/transformer";
import DLoadMore from "discourse/ui-kit/d-load-more";
import DUserAvatar from "discourse/ui-kit/d-user-avatar";
import DUserLink from "discourse/ui-kit/d-user-link";
import dIcon from "discourse/ui-kit/helpers/d-icon";

const PAGE_SIZE = 30;
const FALLBACK_SKELETON_ROWS = 3;

const SkeletonRow = <template>
  <div
    class="post-users-popup__item post-users-popup__skeleton-item"
    aria-hidden="true"
  >
    <div class="post-users-popup__skeleton-avatar"></div>
    <div class="post-users-popup__user-info">
      <div class="post-users-popup__skeleton-name"></div>
      {{#unless @prioritizeUsername}}
        <div class="post-users-popup__skeleton-username"></div>
      {{/unless}}
    </div>
    <div class="post-users-popup__skeleton-reaction"></div>
  </div>
</template>;

export default class PostUsersMenu extends Component {
  @service siteSettings;
  @service site;

  @tracked users = [];
  @tracked loading = false;
  @tracked canLoadMore = true;
  @tracked bodyMinHeight = null;

  displayName = (user) => {
    let defaultName;
    if (user.name && !this.siteSettings.prioritize_username_in_ux) {
      defaultName = user.name;
    } else {
      defaultName = user.username;
    }
    return applyValueTransformer("post-user-display-name", defaultName, {
      user,
    });
  };
  displayUsername = (user) => {
    return applyValueTransformer("post-user-display-username", user.username, {
      user,
    });
  };
  resetAndReload = () => {
    this.users = [];
    this.#page = 0;
    this.canLoadMore = true;
    this.#bodyElement.scrollTop = 0;
    return this.#loadMore();
  };
  #page = 0;
  #bodyElement = null;

  get bodyStyle() {
    if (this.bodyMinHeight) {
      return trustHTML(`min-height: ${this.bodyMinHeight}px`);
    }
    return null;
  }

  get skeletonRows() {
    if (!this.loading) {
      return [];
    }

    const remaining = this.args.totalUsers - this.users.length;
    const count = Number.isFinite(remaining)
      ? Math.min(Math.max(remaining, 0), PAGE_SIZE)
      : FALLBACK_SKELETON_ROWS;
    return Array.from({ length: count });
  }

  @action
  async loadInitial(element) {
    this.#bodyElement = element;
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
        <DLoadMore
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
                <DUserAvatar @user={{user}} @size="small" />
              {{/if}}
              <div class="post-users-popup__user-info">
                <DUserLink
                  @username={{user.username}}
                  class="post-users-popup__name"
                >
                  {{this.displayName user}}
                </DUserLink>
                {{#unless this.siteSettings.prioritize_username_in_ux}}
                  <DUserLink
                    @username={{user.username}}
                    class="post-users-popup__username"
                  >
                    @{{this.displayUsername user}}
                  </DUserLink>
                {{/unless}}
              </div>
              {{#if (has-block "reaction")}}
                {{yield user to="reaction"}}
              {{else}}
                {{dIcon "d-liked" class="post-users-popup__reaction"}}
              {{/if}}
            </div>
          {{/each}}
          {{#each this.skeletonRows}}
            <SkeletonRow
              @prioritizeUsername={{this.siteSettings.prioritize_username_in_ux}}
            />
          {{/each}}
        </DLoadMore>
      </div>
    </div>
  </template>
}
