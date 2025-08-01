import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import PluginOutlet from "discourse/components/plugin-outlet";
import UserAvatar from "discourse/components/user-avatar";
import UserAvatarFlair from "discourse/components/user-avatar-flair";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import lazyHash from "discourse/helpers/lazy-hash";
import { applyValueTransformer } from "discourse/lib/transformer";

export default class PostAvatar extends Component {
  get size() {
    return applyValueTransformer(
      "post-avatar-size",
      this.args.size || "large",
      { post: this.args.post }
    );
  }

  @cached
  get user() {
    const username = this.args.post.username;
    const name = this.args.post.name;
    const path = this.args.post.usernameUrl;
    const avatarTemplate = applyValueTransformer(
      "post-avatar-template",
      this.args.post.avatar_template,
      {
        post: this.args.post,
        keyboardSelected: this.args.keyboardSelected,
        username,
        name,
        path,
        decoratorState: this.args.decoratorState,
      }
    );

    return {
      avatar_template: avatarTemplate,
      username,
      name,
      path,
    };
  }

  get userWasDeleted() {
    return !this.args.post.user_id;
  }

  get additionalClasses() {
    return applyValueTransformer("post-avatar-class", [], {
      post: this.args.post,
      user: this.user,
      userWasDeleted: this.userWasDeleted,
      size: this.size,
    });
  }

  <template>
    <div class={{concatClass "topic-avatar" this.additionalClasses}}>
      {{#let
        (lazyHash
          post=@post
          size=this.size
          user=this.user
          userWasDeleted=this.userWasDeleted
        )
        as |avatarOutletArgs|
      }}
        <PluginOutlet @name="post-avatar" @outletArgs={{avatarOutletArgs}}>
          <div class="post-avatar">
            {{#if this.userWasDeleted}}
              {{icon "trash-can" class="deleted-user-avatar"}}
            {{else}}
              <UserAvatar
                class="main-avatar"
                tabindex="-1"
                @hideTitle={{true}}
                @lazy={{true}}
                @size={{this.size}}
                @user={{this.user}}
              />
              <PluginOutlet
                @name="post-avatar-flair"
                @outletArgs={{avatarOutletArgs}}
              >
                <UserAvatarFlair @user={{this.user}} />
              </PluginOutlet>
            {{/if}}
            {{#if @displayPosterName}}
              <div class="post-avatar-user-info"></div>
            {{/if}}
          </div>
        </PluginOutlet>
      {{/let}}
    </div>
  </template>
}
