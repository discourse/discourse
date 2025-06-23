import Component from "@glimmer/component";
import PluginOutlet from "discourse/components/plugin-outlet";
import UserAvatar from "discourse/components/user-avatar";
import UserAvatarFlair from "discourse/components/user-avatar-flair";
import icon from "discourse/helpers/d-icon";
import lazyHash from "discourse/helpers/lazy-hash";

export default class PostAvatar extends Component {
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

  get userWasDeleted() {
    return !this.args.post.user_id;
  }

  <template>
    <div class="topic-avatar">
      <PluginOutlet
        @name="post-avatar"
        @outletArgs={{lazyHash
          post=@post
          size=this.size
          user=this.user
          userWasDeleted=this.userWasDeleted
        }}
      >
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
            <div>
              <PluginOutlet
                @name="post-avatar-flair"
                @outletArgs={{lazyHash user=this.user}}
              />
            </div>
          {{/if}}
          {{#if @displayPosterName}}
            <div class="post-avatar-user-info"></div>
          {{/if}}
        </div>
      </PluginOutlet>
    </div>
  </template>
}
