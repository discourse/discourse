import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import UserAvatar from "discourse/components/user-avatar";
import DMenu from "discourse/float-kit/components/d-menu";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import lazyHash from "discourse/helpers/lazy-hash";
import { i18n } from "discourse-i18n";

const LIKE_ACTION = 2; // The action type ID for "like" in Discourse
const INITIAL_VISIBLE_USER_COUNT = 20;
const EXPAND_BATCH_SIZES = [20, 40, 60];
const DEFAULT_EXPAND_BATCH_SIZE = 60;
const FETCH_USERS_LIMIT = 60;

export default class LikedUsersList extends Component {
  @service store;

  @tracked likedUsers;
  @tracked loadingLikedUsers = false;
  @tracked visibleUserCount = INITIAL_VISIBLE_USER_COUNT;
  @tracked expansionCount = 0;

  @action
  async fetchLikedUsers() {
    if (this.loadingLikedUsers) {
      return;
    }

    this.loadingLikedUsers = true;

    try {
      this.likedUsers = await this.store.find("post-action-user", {
        id: this.args.post.id,
        post_action_type_id: LIKE_ACTION,
        limit: FETCH_USERS_LIMIT,
      });
      this.visibleUserCount = INITIAL_VISIBLE_USER_COUNT;
      this.expansionCount = 0;
    } finally {
      this.loadingLikedUsers = false;
    }
  }

  @action
  async showMoreLikedUsers() {
    if (!this.likedUsers || this.likedUsers.loadingMore) {
      return;
    }

    const nextVisibleUserCount = this.visibleUserCount + this.nextBatchSize;

    if (
      this.likedUsers.content.length < nextVisibleUserCount &&
      this.likedUsers.canLoadMore
    ) {
      await this.likedUsers.loadMore();
    }

    this.visibleUserCount = Math.min(
      nextVisibleUserCount,
      this.likedUsers.content.length
    );
    this.expansionCount += 1;
  }

  get icon() {
    if (!this.args.post.showLike) {
      return this.args.post.yours ? "d-liked" : "d-unliked";
    }

    if (this.args.post.yours) {
      return "d-liked";
    }
  }

  get visibleUsers() {
    return this.likedUsers?.content.slice(0, this.visibleUserCount);
  }

  get remainingUserCount() {
    return Math.max(this.totalLikedUserCount - this.visibleUserCount, 0);
  }

  get hasMoreUsers() {
    return this.remainingUserCount > 0;
  }

  get usesFixedGrid() {
    return this.totalLikedUserCount > INITIAL_VISIBLE_USER_COUNT;
  }

  get nextBatchSize() {
    return EXPAND_BATCH_SIZES[this.expansionCount] ?? DEFAULT_EXPAND_BATCH_SIZE;
  }

  get totalLikedUserCount() {
    return this.likedUsers?.totalRows ?? this.likedUsers?.content.length ?? 0;
  }

  get showMoreLabel() {
    return i18n("post.liked_users.show_more");
  }

  <template>
    <DMenu
      @modalForMobile={{true}}
      @identifier="post-like-users_{{@post.id}}"
      @onShow={{this.fetchLikedUsers}}
      @triggerClass={{concatClass
        "post-action-menu__like-count"
        "like-count"
        "btn-flat"
        "button-count"
        "highlight-action"
        (if @post.yours "my-likes" "regular-likes")
      }}
      @icon={{if @post.yours "d-liked" ""}}
      @placement="top"
      @contentClass="liked-users-list-menu"
      label={{i18n "post.sr_post_like_count_button" count=@post.likeCount}}
      id="post-like-users_{{@post.id}}"
    >
      <:trigger>
        {{@post.likeCount}}
      </:trigger>
      <:content>
        <ConditionalLoadingSpinner
          @condition={{this.loadingLikedUsers}}
          class="liked-users-list__container"
        >
          <div class="liked-users-list">
            <ul
              class={{concatClass
                "liked-users-list__list"
                (if this.usesFixedGrid "liked-users-list__list--fixed-grid")
              }}
            >
              <li class="liked-users-list__count-item">
                <span class="liked-users-list__count">
                  {{icon "d-liked" class="liked-users-list__count-icon"}}
                  {{this.totalLikedUserCount}}
                </span>
              </li>
              {{#each this.visibleUsers as |user|}}
                <li class="liked-users-list__item">
                  <PluginOutlet
                    @name="liked-users-list-avatar"
                    @outletArgs={{lazyHash user=user post=@post}}
                  >
                    <UserAvatar
                      class="trigger-user-card liked-users-list__avatar"
                      @user={{user}}
                      @size="small"
                    />
                  </PluginOutlet>
                </li>
              {{/each}}
            </ul>
            {{#if this.hasMoreUsers}}
              <div class="liked-users-list__controls">
                <DButton
                  class="liked-users-list__show-more-button"
                  @display="link"
                  @action={{this.showMoreLikedUsers}}
                  @isLoading={{this.likedUsers.loadingMore}}
                  @translatedLabel={{this.showMoreLabel}}
                  @translatedAriaLabel={{this.showMoreLabel}}
                />
              </div>
            {{/if}}
          </div>
        </ConditionalLoadingSpinner>
      </:content>
    </DMenu>
  </template>
}
