import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { service } from "@ember/service";
import { eq } from "truth-helpers";
import AvatarFlair from "discourse/components/avatar-flair";
import avatar from "discourse/helpers/avatar";
import concatClass from "discourse/helpers/concat-class";
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
      class={{concatClass
        "event-invitee"
        (if @invitee.status (concat "status-" @invitee.status))
        (if (eq this.currentUser.id @invitee.user.id) "is-current-user")
      }}
    >
      <a class="topic-invitee-avatar" data-user-card={{@invitee.user.username}}>
        {{avatar
          @invitee.user
          imageSize=(if this.site.mobileView "tiny" "large")
        }}
        {{#if this.statusIcon}}
          <AvatarFlair
            @flairName={{this.flairName}}
            @flairUrl={{this.statusIcon}}
          />
        {{/if}}
      </a>
    </li>
  </template>
}
