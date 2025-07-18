import Component from "@glimmer/component";
import avatar from "discourse/helpers/avatar";
import { formatUsername } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

export default class DiscoursePostEventCreator extends Component {
  get username() {
    return this.args.user.name || formatUsername(this.args.user.username);
  }

  <template>
    <span class="creators">
      <span class="created-by">{{i18n "discourse_post_event.created_by"}}</span>

      <span class="event-creator">
        <a class="topic-invitee-avatar" data-user-card={{@user.username}}>
          {{avatar @user imageSize="tiny"}}
          <span class="username">{{this.username}}</span>
        </a>
      </span>
    </span>
  </template>
}
