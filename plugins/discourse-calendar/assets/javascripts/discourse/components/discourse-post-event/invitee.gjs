import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { service } from "@ember/service";
import { eq } from "discourse/truth-helpers";
import DAvatarFlair from "discourse/ui-kit/d-avatar-flair";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

export default class DiscoursePostEventInvitee extends Component {
  @service site;
  @service currentUser;

  get statusIcon() {
    switch (this.args.invitee.status) {
      case "going":
        return "check";
      case "interested":
        return "star";
      case "not_going":
        return "xmark";
    }
  }

  get flairName() {
    const string = `discourse_post_event.models.invitee.status.${this.args.invitee.status}`;

    return i18n(string);
  }

  <template>
    <li
      class={{dConcatClass
        "event-invitee"
        (if @invitee.status (concat "status-" @invitee.status))
        (if (eq this.currentUser.id @invitee.user.id) "is-current-user")
      }}
    >
      <a class="topic-invitee-avatar" data-user-card={{@invitee.user.username}}>
        {{dAvatar
          @invitee.user
          imageSize=(if this.site.mobileView "tiny" "large")
        }}
        {{#if this.statusIcon}}
          <DAvatarFlair
            @flairName={{this.flairName}}
            @flairUrl={{this.statusIcon}}
          />
        {{/if}}
      </a>
    </li>
  </template>
}
