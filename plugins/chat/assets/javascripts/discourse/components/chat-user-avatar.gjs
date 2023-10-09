import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { renderAvatar } from "discourse/helpers/user-avatar";
import { htmlSafe } from "@ember/template";
import concatClass from "discourse/helpers/concat-class";

export default class ChatUserAvatar extends Component {
  <template>
    <div
      class={{concatClass "chat-user-avatar" (if this.isOnline "is-online")}}
    >
      {{log this.interactive}}
      {{#if this.interactive}}
        <div
          role="button"
          class="chat-user-avatar__container clickable"
          data-user-card={{@user.username}}
        >
          {{this.avatar}}
        </div>
      {{else}}
        {{this.avatar}}
      {{/if}}
    </div>
  </template>

  @service chat;

  get avatar() {
    return htmlSafe(
      renderAvatar(this.args.user, { imageSize: this.avatarSize })
    );
  }

  get interactive() {
    console.log(this.args.interactive);
    return this.args.interactive ?? true;
  }

  get avatarSize() {
    return this.args.avatarSize || "tiny";
  }

  get showPresence() {
    return this.args.showPresence ?? true;
  }

  get isOnline() {
    const users = (this.args.chat || this.chat).presenceChannel?.users;

    return (
      this.showPresence &&
      !!users?.find(
        ({ id, username }) =>
          this.args.user?.id === id || this.args.user?.username === username
      )
    );
  }
}
