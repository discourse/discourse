import Component from "@glimmer/component";
import PluginOutlet from "discourse/components/plugin-outlet";
import UserAvatar from "discourse/components/user-avatar";
import lazyHash from "discourse/helpers/lazy-hash";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";
import PostUsersMenu from "./post-users-menu";

const LIKE_ACTION = 2;

export default class PostLikedUsersMenu extends Component {
  fetchUsers = async (page, pageSize) => {
    const result = await ajax("/post_action_users", {
      data: {
        id: this.post.id,
        post_action_type_id: LIKE_ACTION,
        page,
        limit: pageSize,
      },
    });

    const newUsers = result.post_action_users ?? [];
    const canLoadMore =
      newUsers.length >= pageSize && !!result.total_rows_post_action_users;
    return { users: newUsers, canLoadMore };
  };

  get post() {
    return this.args.data.post;
  }

  get titleText() {
    return i18n("post.likes_popup.title", {
      count: this.post.likeCount,
    });
  }

  <template>
    <PostUsersMenu
      @fetchUsers={{this.fetchUsers}}
      @titleText={{this.titleText}}
    >
      <:avatar as |user|>
        <PluginOutlet
          @name="liked-users-list-avatar"
          @outletArgs={{lazyHash user=user post=this.post}}
        >
          <UserAvatar class="trigger-user-card" @user={{user}} @size="small" />
        </PluginOutlet>
      </:avatar>
    </PostUsersMenu>
  </template>
}
