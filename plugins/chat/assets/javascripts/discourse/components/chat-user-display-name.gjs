import Component from "@glimmer/component";
import { service } from "@ember/service";
import concatClass from "discourse/helpers/concat-class";
import { formatUsername } from "discourse/lib/utilities";

export default class ChatUserDisplayName extends Component {
  @service siteSettings;

  get shouldPrioritizeNameInUx() {
    return !this.siteSettings.prioritize_username_in_ux;
  }

  get hasValidName() {
    return this.args.user?.name && this.args.user.name.trim().length > 0;
  }

  get formattedUsername() {
    return formatUsername(this.args.user?.username);
  }

  get shouldShowNameFirst() {
    return this.shouldPrioritizeNameInUx && this.hasValidName;
  }

  get shouldShowNameLast() {
    return !this.shouldPrioritizeNameInUx && this.hasValidName;
  }

  <template>
    <span class="chat-user-display-name">
      {{#if this.shouldShowNameFirst}}
        <span class="chat-user-display-name__name -first">{{@user.name}}</span>
      {{/if}}

      <span
        class={{concatClass
          "chat-user-display-name__username"
          (unless this.shouldShowNameFirst "-first")
        }}
      >
        {{this.formattedUsername}}
      </span>

      {{#if this.shouldShowNameLast}}
        <span class="chat-user-display-name__name">{{@user.name}}</span>
      {{/if}}
    </span>
  </template>
}
