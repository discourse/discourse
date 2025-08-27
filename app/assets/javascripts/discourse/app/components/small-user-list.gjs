import Component from "@glimmer/component";
import { service } from "@ember/service";
import PluginOutlet from "discourse/components/plugin-outlet";
import avatar from "discourse/helpers/bound-avatar-template";
import getURL from "discourse/lib/get-url";
import { applyValueTransformer } from "discourse/lib/transformer";
import { userPath } from "discourse/lib/url";
import { i18n } from "discourse-i18n";

export function smallUserAttrs(user) {
  const defaultAttrs = {
    template: user.avatar_template,
    username: user.username,
    post_url: user.post_url,
    url: userPath(user.username_lower),
    unknown: user.unknown,
  };

  return applyValueTransformer("small-user-attrs", defaultAttrs, {
    user,
  });
}

export default class SmallUserList extends Component {
  @service currentUser;

  get users() {
    let users = this.args.users;
    if (
      this.args.addSelf &&
      !users.some((u) => u.username === this.currentUser.username)
    ) {
      users = users.concat(smallUserAttrs(this.currentUser));
    }
    return users;
  }

  get postUrl() {
    const url = this.users.find((user) => user.post_url);
    if (url) {
      return getURL(url);
    }
  }

  get shouldShow() {
    return this.users.length && (this.args.isVisible ?? true);
  }

  <template>
    <PluginOutlet @name="small-user-list-internal" @outletArgs={{this.args}}>
      <div
        class="small-user-list {{if this.shouldShow '--expanded'}}"
        ...attributes
      >
        <span
          class="small-user-list-content"
          role="list"
          aria-live="polite"
          aria-atomic="true"
        >
          {{#if this.shouldShow}}
            {{#each this.users key="username" as |user|}}
              {{#if user.unknown}}
                <div
                  title={{i18n "post.unknown_user"}}
                  class="unknown"
                  role="listitem"
                ></div>
              {{else}}
                <a
                  class="trigger-user-card"
                  data-user-card={{user.username}}
                  title={{user.username}}
                  aria-hidden="false"
                  role="listitem"
                >
                  {{avatar user.template "tiny"}}
                </a>
              {{/if}}
            {{/each}}

            {{#if @description}}
              {{#if this.postUrl}}
                <a href={{this.postUrl}}>
                  <span class="list-description">
                    {{i18n @description count=@count}}
                  </span>
                </a>
              {{else}}
                <span class="list-description">
                  {{i18n @description count=@count}}
                </span>
              {{/if}}
            {{/if}}
          {{/if}}
        </span>
      </div>
    </PluginOutlet>
  </template>
}
