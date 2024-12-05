import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { service } from "@ember/service";
import PluginOutlet from "discourse/components/plugin-outlet";
import avatar from "discourse/helpers/bound-avatar-template";
import { smallUserAttrs } from "discourse/lib/user-list-attrs";
import i18n from "discourse-common/helpers/i18n";
import getURL from "discourse-common/lib/get-url";

export default class SmallUserList extends Component {
  @service currentUser;

  get users() {
    let users = this.args.data.users;
    if (
      this.args.data.addSelf &&
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

  <template>
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
          {{#each this.users as |user|}}
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

          {{#if @data.description}}
            {{#if this.postUrl}}
              <a href={{this.postUrl}}>
                <span aria-hidden="true" class="list-description">
                  {{i18n @data.description count=@data.count}}
                </span>
              </a>
            {{else}}
              <span aria-hidden="true" class="list-description">
                {{i18n @data.description count=@data.count}}
              </span>
            {{/if}}
          {{/if}}
        </span>
      </div>
    </PluginOutlet>
  </template>
}
