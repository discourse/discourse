import Component from "@glimmer/component";
import { service } from "@ember/service";
import userPrioritizedName from "discourse/helpers/user-prioritized-name";
import DInterpolatedTranslation from "discourse/ui-kit/d-interpolated-translation";
import DRelativeDate from "discourse/ui-kit/d-relative-date";
import DUserLink from "discourse/ui-kit/d-user-link";
import dBoundAvatarTemplate from "discourse/ui-kit/helpers/d-bound-avatar-template";
import { i18n } from "discourse-i18n";

export default class SolvedAccordionItemMetadata extends Component {
  @service siteSettings;

  get post() {
    return this.args.post;
  }

  get userDisplayName() {
    return userPrioritizedName({
      username: this.post.username,
      name: this.post.name,
    });
  }

  get accepterDisplayName() {
    return userPrioritizedName({
      username: this.post.accepter_username,
      name: this.post.accepter_name,
    });
  }

  get showAccepter() {
    return (
      !!this.siteSettings.show_who_marked_solved && this.post.accepter_username
    );
  }

  <template>
    <DUserLink class="user-link" @username={{this.post.username}}>
      {{dBoundAvatarTemplate this.post.avatar_template "tiny"}}
      <span>{{this.userDisplayName}}</span>
    </DUserLink>
    <span class="dot-separator"></span>
    <a class="date-link" href={{this.post.url}} title={{i18n "post.sr_date"}}>
      <DRelativeDate @date={{this.post.created_at}} />
    </a>

    {{#if this.showAccepter}}
      <span class="dot-separator"></span>

      <span class="accepter-name">
        <DInterpolatedTranslation
          @key="solved.marked_solved_by"
          as |Placeholder|
        >
          <Placeholder @name="user">

            <DUserLink
              class="accepter-link"
              @username={{this.post.accepter_username}}
            >
              {{this.accepterDisplayName}}
            </DUserLink>
          </Placeholder>
        </DInterpolatedTranslation>
      </span>
    {{/if}}
  </template>
}
