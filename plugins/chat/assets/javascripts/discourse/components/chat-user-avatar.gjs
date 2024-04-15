import Component from "@glimmer/component";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import concatClass from "discourse/helpers/concat-class";
import { renderAvatar } from "discourse/helpers/user-avatar";
import { userPath } from "discourse/lib/url";

export default class ChatUserAvatar extends Component {
  @service chat;

  get avatar() {
    return htmlSafe(
      renderAvatar(this.args.user, { imageSize: this.avatarSize })
    );
  }

  get interactive() {
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

  get userPath() {
    return userPath(this.args.user.username);
  }

  <template>
    <div
      class={{concatClass "chat-user-avatar" (if this.isOnline "is-online")}}
      data-username={{@user.username}}
    >
      {{#if this.interactive}}
        <a
          class="chat-user-avatar__container"
          href={{this.userPath}}
          data-user-card={{@user.username}}
        >
          {{this.avatar}}
        </a>
      {{else}}
        <span class="chat-user-avatar__container">
          {{this.avatar}}
        </span>
      {{/if}}
    </div>
  </template>
}
