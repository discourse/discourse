import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
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
    {{#each this.usersTemplates as |userTemplate|}}
      <div data-username={{userTemplate.username}} class="user-info small">
        <div class="user-image">
          <div class="user-image-inner">
            <a
              href={{userTemplate.userPath}}
              data-user-card={{userTemplate.username}}
              aria-hidden="true"
            >
              {{html-safe userTemplate.avatar}}
            </a>
          </div>
        </div>
        <div class="user-detail">
          <div class="name-line">
            <a
              href={{userTemplate.userPath}}
              data-user-card={{userTemplate.username}}
              aria-label={{i18n
                "user.profile_possessive"
                username=userTemplate.username
              }}
            >
              <span class="username">
                {{#if userTemplate.prioritizeName}}
                  {{userTemplate.name}}
                {{else}}
                  {{userTemplate.username}}
                {{/if}}
              </span>
              <span class="name">
                {{#if userTemplate.prioritizeName}}
                  {{userTemplate.username}}
                {{else}}
                  {{userTemplate.name}}
                {{/if}}
              </span>
            </a>
          </div>
          <div class="title">{{userTemplate.title}}</div>
        </div>
      </div>
    {{/each}}
  </template>
}
