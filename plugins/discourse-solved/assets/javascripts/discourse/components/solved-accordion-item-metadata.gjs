import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { service } from "@ember/service";
import InterpolatedTranslation from "discourse/components/interpolated-translation";
import RelativeDate from "discourse/components/relative-date";
import UserLink from "discourse/components/user-link";
import boundAvatarTemplate from "discourse/helpers/bound-avatar-template";
import userPrioritizedName from "discourse/helpers/user-prioritized-name";
import User from "discourse/models/user";
import { i18n } from "discourse-i18n";

export default class SolvedAccordionItemMetadata extends Component {
  @service siteSettings;

  get excerptPost() {
    return this.args.excerptPost;
  }

  @cached
  get user() {
    return User.create(this.excerptPost.user);
  }

  get userDisplayName() {
    return userPrioritizedName(this.user);
  }

  @cached
  get accepter() {
    return User.create(this.excerptPost.accepter);
  }

  get accepterDisplayName() {
    return userPrioritizedName(this.accepter);
  }

  get showAccepter() {
    return !!this.siteSettings.show_who_marked_solved;
  }

  <template>
    <UserLink @user={{this.excerptPost.user}}>
      {{boundAvatarTemplate this.excerptPost.user.avatar_template "tiny"}}
      <span class="user-name">
        {{this.userDisplayName}}
      </span>
    </UserLink>
    <span class="dot-separator"></span>
    <a href={{this.excerptPost.post_url}} title={{i18n "post.sr_date"}}>
      <RelativeDate @date={{this.excerptPost.displayDate}} />
    </a>

    {{#if this.showAccepter}}
      <span class="dot-separator"></span>

      <span class="accepter-name">
        <InterpolatedTranslation
          @key="solved.marked_solved_by"
          as |Placeholder|
        >
          <Placeholder @name="user" @class="d-solved-accordion__accepter">

            <UserLink @user={{this.accepter}}>
              {{this.accepterDisplayName}}
            </UserLink>
          </Placeholder>
        </InterpolatedTranslation>
      </span>
    {{/if}}
  </template>
}
