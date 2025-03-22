import Component from "@glimmer/component";
import UserAvatar from "discourse/components/user-avatar";
import UserAvatarFlair from "discourse/components/user-avatar-flair";
import icon from "discourse/helpers/d-icon";

export default class PostAvatar extends Component {
  get userWasDeleted() {
    return !this.args.post.user_id;
  }

  get size() {
    return this.args.size || "large";
  }

  get user() {
    return {
      avatar_template: this.args.post.avatar_template,
      username: this.args.post.username,
      name: this.args.post.name,
      path: this.args.post.usernameUrl,
    };
  }

  <template>
    <div class="topic-avatar">
      <div class="post-avatar">
        {{#if this.userWasDeleted}}
          {{icon "trash-can" class="deleted-user-avatar"}}
        {{else}}
          <UserAvatar
            tabindex="-1"
            @hideTitle={{true}}
            @lazy={{true}}
            @avatarClasses="main-avatar"
            @size={{this.size}}
            @user={{this.user}}
          />
          <UserAvatarFlair @user={{@post}} />
        {{/if}}
        {{#if @displayPosterName}}
          <div class="post-avatar-user-info"></div>
        {{/if}}
      </div>
    </div>
  </template>
}
