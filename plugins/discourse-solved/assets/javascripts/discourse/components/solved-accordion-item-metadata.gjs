import Component from "@glimmer/component";
import { service } from "@ember/service";
import InterpolatedTranslation from "discourse/components/interpolated-translation";
import RelativeDate from "discourse/components/relative-date";
import UserLink from "discourse/components/user-link";
import boundAvatarTemplate from "discourse/helpers/bound-avatar-template";
import userPrioritizedName from "discourse/helpers/user-prioritized-name";
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
    <UserLink @username={{this.excerptPost.username}} class="user-link">
      {{boundAvatarTemplate this.excerptPost.avatar_template "tiny"}}
      <span>{{this.userDisplayName}}</span>
    </UserLink>
    <span class="dot-separator"></span>
    <a href={{this.excerptPost.post_url}} title={{i18n "post.sr_date"}}>
      <RelativeDate @date={{this.excerptPost.created_at}} />
    </a>

    {{#if this.showAccepter}}
      <span class="dot-separator"></span>

      <span class="accepter-name">
        <InterpolatedTranslation
          @key="solved.marked_solved_by"
          as |Placeholder|
        >
          <Placeholder @name="user" @class="d-solved-answers__accepter">

            <UserLink
              @username={{this.excerptPost.accepter_username}}
              class="accepter-link"
            >
              {{this.accepterDisplayName}}
            </UserLink>
          </Placeholder>
        </InterpolatedTranslation>
      </span>
    {{/if}}
  </template>
}
