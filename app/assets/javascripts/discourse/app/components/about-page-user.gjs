import Component from "@glimmer/component";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { renderAvatar } from "discourse/helpers/user-avatar";
import { prioritizeNameInUx } from "discourse/lib/settings";
import { userPath } from "discourse/lib/url";
import i18n from "discourse-common/helpers/i18n";

export default class AboutPageUser extends Component {
  @service siteSettings;

  get template() {
    const user = this.args.user;
    return {
      name: user.name,
      username: user.username,
      userPath: userPath(user.username),
      avatar: renderAvatar(user, {
        imageSize: "large",
        siteSettings: this.siteSettings,
      }),
      title: user.title || "",
      prioritizeName: prioritizeNameInUx(user.name),
    };
  }

  <template>
    <div data-username={{this.template.username}} class="user-info small">
      <div class="user-image">
        <div class="user-image-inner">
          <a
            href={{this.template.userPath}}
            data-user-card={{this.template.username}}
            aria-hidden="true"
          >
            {{htmlSafe this.template.avatar}}
          </a>
        </div>
      </div>
      <div class="user-detail">
        <div class="name-line">
          <a
            href={{this.template.userPath}}
            data-user-card={{this.template.username}}
            aria-label={{i18n
              "user.profile_possessive"
              username=this.template.username
            }}
          >
            <span class="username">
              {{#if this.template.prioritizeName}}
                {{this.template.name}}
              {{else}}
                {{this.template.username}}
              {{/if}}
            </span>
            <span class="name">
              {{#if this.template.prioritizeName}}
                {{this.template.username}}
              {{else}}
                {{this.template.name}}
              {{/if}}
            </span>
          </a>
        </div>
        <div class="title">{{this.template.title}}</div>
      </div>
    </div>
  </template>
}
