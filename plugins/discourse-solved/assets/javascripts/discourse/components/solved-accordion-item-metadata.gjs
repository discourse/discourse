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

  get excerptPost() {
    return this.args.excerptPost;
  }

  get userDisplayName() {
    return userPrioritizedName({
      username: this.excerptPost.username,
      name: this.excerptPost.name,
    });
  }

  get accepterDisplayName() {
    return userPrioritizedName({
      username: this.excerptPost.accepter_username,
      name: this.excerptPost.accepter_name,
    });
  }

  get showAccepter() {
    return (
      !!this.siteSettings.show_who_marked_solved &&
      this.excerptPost.accepter_username
    );
  }

  <template>
    <DUserLink @username={{this.excerptPost.username}} class="user-link">
      {{dBoundAvatarTemplate this.excerptPost.avatar_template "tiny"}}
      <span>{{this.userDisplayName}}</span>
    </DUserLink>
    <span class="dot-separator"></span>
    <a href={{this.excerptPost.url}} title={{i18n "post.sr_date"}}>
      <DRelativeDate @date={{this.excerptPost.created_at}} />
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
              @username={{this.excerptPost.accepter_username}}
              class="accepter-link"
            >
              {{this.accepterDisplayName}}
            </DUserLink>
          </Placeholder>
        </DInterpolatedTranslation>
      </span>
    {{/if}}
  </template>
}
