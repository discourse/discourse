import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { service } from "@ember/service";
import PluginOutlet from "discourse/components/plugin-outlet";
import avatar from "discourse/helpers/bound-avatar-template";
import i18n from "discourse-common/helpers/i18n";
import getURL from "discourse-common/lib/get-url";

export default class SmallUserList extends Component {
  @service currentUser;
  @service userListAtts;

  get users() {
    let users = this.args.users;
    if (
      this.args.addSelf &&
      !users.some((u) => u.username === this.currentUser.username)
    ) {
      users = users.concat(this.userListAtts.smallUserAtts(this.currentUser));
    }
    return users;
  }

  get postUrl() {
    const url = this.users.find((user) => user.post_url);
    if (url) {
      return getURL(url);
    }
  }

  <template>
    {{#if this.users}}
      <PluginOutlet
        @name="small-user-list-internal"
        @outletArgs={{hash data=this.args}}
      >
        <div class="clearfix small-user-list" ...attributes>
          <span
            class="small-user-list-content"
            aria-label={{@ariaLabel}}
            role="list"
          >
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
                  <span aria-hidden="true" class="list-description">
                    {{i18n @description count=@count}}
                  </span>
                </a>
              {{else}}
                <span aria-hidden="true" class="list-description">
                  {{i18n @description count=@count}}
                </span>
              {{/if}}
            {{/if}}
          </span>
        </div>
      </PluginOutlet>
    {{/if}}
  </template>
}
