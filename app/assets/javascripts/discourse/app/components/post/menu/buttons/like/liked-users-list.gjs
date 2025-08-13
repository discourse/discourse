import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import icon from "discourse/helpers/d-icon";
import DMenu from "float-kit/components/d-menu";
import LikedUserItem from "./liked-user-item";

export default class LikedUsersList extends Component {
  @service store;

  @tracked likedUsers = null;
  @tracked loadingLikedUsers = false;

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
          post_action_type_id: 2, // LIKE_ACTION
        })
        .then((result) => result.toArray());

      this.likedUsers = users;
    } catch {
    } finally {
      this.loadingLikedUsers = false;
    }
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
          <ul class="liked-users-list">
            {{#each this.likedUsers as |user|}}
              <li class="liked-users-list__item">
                <LikedUserItem @user={{user}} />
              </li>
            {{/each}}
          </ul>
        </ConditionalLoadingSpinner>
      </:content>
    </DMenu>
  </template>
}
