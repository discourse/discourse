import Component from "@glimmer/component";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { renderAvatar } from "discourse/helpers/user-avatar";
import { prioritizeNameInUx } from "discourse/lib/settings";
import { userPath } from "discourse/lib/url";
import i18n from "discourse-common/helpers/i18n";

export default class AboutPageUsers extends Component {
  @service siteSettings;

  get usersTemplates() {
    return (this.args.users || []).map((user) => ({
      name: user.name,
      username: user.username,
      userPath: userPath(user.username),
      avatar: renderAvatar(user, {
        imageSize: "large",
        siteSettings: this.siteSettings,
      }),
      title: user.title || "",
      prioritizeName: prioritizeNameInUx(user.name),
    }));
  }

  <template>
    {{#each this.usersTemplates as |template|}}
      <div data-username={{template.username}} class="user-info small">
        <div class="user-image">
          <div class="user-image-inner">
            <a
              href={{template.userPath}}
              data-user-card={{template.username}}
              aria-hidden="true"
            >
              {{htmlSafe template.avatar}}
            </a>
          </div>
        </div>
        <div class="user-detail">
          <div class="name-line">
            <a
              href={{template.userPath}}
              data-user-card={{template.username}}
              aria-label={{i18n
                "user.profile_possessive"
                username=template.username
              }}
            >
              <span class="username">
                {{#if template.prioritizeName}}
                  {{template.name}}
                {{else}}
                  {{template.username}}
                {{/if}}
              </span>
              <span class="name">
                {{#if template.prioritizeName}}
                  {{template.username}}
                {{else}}
                  {{template.name}}
                {{/if}}
              </span>
            </a>
          </div>
          <div class="title">{{template.title}}</div>
        </div>
      </div>
    {{/each}}
  </template>
}
