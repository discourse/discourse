import Component from "@glimmer/component";
import { service } from "@ember/service";
import UserAvatarFlair from "discourse/components/user-avatar-flair";
import UserLink from "discourse/components/user-link";
import avatar from "discourse/helpers/avatar";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";

export default class PostAvatar extends Component {
  @service currentUser;
  @service siteSettings;

  get hideFromAnonUser() {
    return (
      this.siteSettings.hide_user_profiles_from_public && !this.currentUser
    );
  }

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
          <UserLink tabindex="-1" @user={{this.user}}>
            {{avatar
              this.user
              imageSize=this.size
              loading="lazy"
              hideTitle=true
              extraClasses=(concatClass
                "main-avatar" (if this.hideFromAnonUser "non-clickable")
              )
            }}
          </UserLink>
          <UserAvatarFlair @user={{@post}} />
        {{/if}}
        {{#if @displayPosterName}}
          <div class="post-avatar-user-info">

          </div>
        {{/if}}
      </div>
    </div>
  </template>
}
