import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import UserAvatar from "discourse/components/user-avatar";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import DMenu from "float-kit/components/d-menu";

const LIKE_ACTION = 2; // The action type ID for "like" in Discourse
const DISPLAY_MAX_USERS = 8; // will show X users, then a button to show one more row of X;

export default class LikedUsersList extends Component {
  @service store;

  @tracked likedUsers;
  @tracked loadingLikedUsers = false;
  @tracked slicedUsersVisible = false;

  @action
  async fetchLikedUsers() {
    if (this.likedUsers || this.loadingLikedUsers) {
      return;
    }

    this.loadingLikedUsers = true;

    try {
      const users = await this.store
        .find("post-action-user", {
          id: this.args.post.id,
          post_action_type_id: LIKE_ACTION,
        })
        .then((result) => result);

      this.likedUsers = users;
    } finally {
      this.loadingLikedUsers = false;
    }
  }

  @action
  toggleSlicedUsersVisiblity() {
    this.slicedUsersVisible = !this.slicedUsersVisible;
  }

  get truncatedUsers() {
    return this.likedUsers?.slice(0, DISPLAY_MAX_USERS);
  }

  get slicedUsers() {
    return this.likedUsers?.slice(DISPLAY_MAX_USERS, DISPLAY_MAX_USERS * 2);
  }

  get hiddenUserCount() {
    return (
      this.likedUsers?.length -
      (this.truncatedUsers.length + this.slicedUsers.length)
    );
  }

  get toggleSlicedUsersVisiblityIcon() {
    return this.slicedUsersVisible ? "angle-up" : "angle-down";
  }

  <template>
    <DMenu
      @modalForMobile={{true}}
      @identifier="post-like-users"
      @triggers="click"
      @onShow={{this.fetchLikedUsers}}
      @triggerClass="button-count"
      @placement="top"
    >
      <:trigger>
        {{@post.likeCount}}
      </:trigger>
      <:content>
        <ConditionalLoadingSpinner
          @condition={{this.loadingLikedUsers}}
          class="liked-users-list__container"
        >
          <span class="liked-users-list__count">
            {{icon "d-liked" class="liked-users-list__count-icon"}}
            {{@post.likeCount}}
          </span>
          <div class="liked-users-list">
            <ul class="liked-users-list__list">
              {{#each this.truncatedUsers as |user|}}
                <li class="liked-users-list__item">
                  <UserAvatar
                    class="trigger-user-card"
                    @user={{user}}
                    @size="small"
                  />
                </li>
              {{/each}}
              {{#if this.slicedUsers}}
                <li class="liked-users-list__item">
                  <DButton
                    class="liked-users-list__more-button btn-flat"
                    @icon={{this.toggleSlicedUsersVisiblityIcon}}
                    @action={{this.toggleSlicedUsersVisiblity}}
                  />
                </li>
              {{/if}}
            </ul>
            {{#if this.slicedUsersVisible}}
              <ul class="liked-users-list__list">
                {{#each this.slicedUsers as |user|}}
                  <li class="liked-users-list__item">
                    <UserAvatar
                      class="trigger-user-card"
                      @user={{user}}
                      @size="small"
                    />
                  </li>
                {{/each}}
              </ul>
              {{#if this.hiddenUserCount}}
                <span class="liked-users-list__more">
                  {{i18n
                    "discourse_reactions.state_panel.more_users"
                    count=this.hiddenUserCount
                  }}
                </span>
              {{/if}}
            {{/if}}
          </div>
        </ConditionalLoadingSpinner>
      </:content>
    </DMenu>
  </template>
}
