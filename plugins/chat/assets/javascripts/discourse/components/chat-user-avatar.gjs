import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import UserCard from "discourse/components/user-card";
import concatClass from "discourse/helpers/concat-class";
import { renderAvatar } from "discourse/helpers/user-avatar";

export default class ChatUserAvatar extends Component {
  @service chat;
  @service card;

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

  @action
  showCard(event) {
    this.card.show(UserCard, event.target, {
      model: { user: this.args.user },
    });
  }

  <template>
    <div
      class={{concatClass "chat-user-avatar" (if this.isOnline "is-online")}}
      data-username={{@user.username}}
    >
      {{#if this.interactive}}
        <div
          role="button"
          class="chat-user-avatar__container"
          {{on "click" this.showCard}}
        >
          {{this.avatar}}
        </div>
      {{else}}
        {{this.avatar}}
      {{/if}}
    </div>
  </template>
}
