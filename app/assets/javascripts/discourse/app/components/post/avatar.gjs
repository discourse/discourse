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
  @cached
  get user() {
    const user = this.args.post.user;
    if (!user) {
      return null;
    }

    const avatarTemplate = applyValueTransformer(
      "post-avatar-template",
      user.avatar_template,
      this.#transformerContext(user)
    );

    if (avatarTemplate !== user.avatar_template) {
      // returns a proxy object to user which overrides the avatarTemplate
      return new Proxy(user, {
        get(target, prop) {
          if (prop === "avatar_template") {
            return avatarTemplate;
          }
          return target[prop];
        },
      });
    }

    // if the template is unchanged, return the original user object directly
    return user;
  }

  get size() {
    return applyValueTransformer(
      "post-avatar-size",
      this.args.size || "large",
      this.#transformerContext()
    );
  }

  get userWasDeleted() {
    return !this.args.post.user;
  }

  get additionalClasses() {
    return applyValueTransformer(
      "post-avatar-class",
      [],
      this.#transformerContext()
    );
  }

  #transformerContext(user = this.user) {
    return {
      decoratorState: this.args.decoratorState,
      keyboardSelected: this.args.keyboardSelected,
      post: this.args.post,
      user,
      userWasDeleted: this.userWasDeleted,
    };
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
