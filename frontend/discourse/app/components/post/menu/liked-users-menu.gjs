import Component from "@glimmer/component";
import PluginOutlet from "discourse/components/plugin-outlet";
import UsersPopup from "discourse/components/user/users-popup";
import lazyHash from "discourse/helpers/lazy-hash";
import { ajax } from "discourse/lib/ajax";
import DUserAvatar from "discourse/ui-kit/d-user-avatar";
import { i18n } from "discourse-i18n";

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
    <UsersPopup
      @fetchUsers={{this.fetchUsers}}
      @titleText={{this.titleText}}
      @totalUsers={{this.post.likeCount}}
    >
      <:avatar as |user|>
        <PluginOutlet
          @name="liked-users-list-avatar"
          @outletArgs={{lazyHash user=user post=this.post}}
        >
          <DUserAvatar class="trigger-user-card" @user={{user}} @size="small" />
        </PluginOutlet>
      </:avatar>
    </UsersPopup>
  </template>
}
