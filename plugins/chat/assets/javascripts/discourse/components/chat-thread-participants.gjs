import Component from "@glimmer/component";
import { i18n } from "discourse-i18n";
import ChatUserAvatar from "discourse/plugins/chat/discourse/components/chat-user-avatar";

export default class ChatThreadParticipants extends Component {
  get showParticipants() {
    if (!this.args.thread) {
      return;
    }

    if (this.includeOriginalMessageUser) {
      return this.participantsUsers.length > 1;
    }

    return this.participantsUsers.length > 0;
  }

  get includeOriginalMessageUser() {
    return this.args.includeOriginalMessageUser ?? true;
  }

  get participantsUsers() {
    const users = this.args.thread.preview.participantUsers;

    if (this.includeOriginalMessageUser) {
      if (users.length > 3) {
        return users.slice(0, 2).concat(users[users.length - 1]);
      } else {
        return users;
      }
    }

    return users.filter((user) => {
      return user.id !== this.args.thread.originalMessage.user.id;
    });
  }

  get otherCountLabel() {
    return i18n("chat.thread.participants_other_count", {
      count: this.args.thread.preview.otherParticipantCount,
    });
  }

  <template>
    {{#if this.showParticipants}}
      <div class="chat-thread-participants" ...attributes>
        <div class="chat-thread-participants__avatar-group">
          {{#each this.participantsUsers as |user|}}
            <ChatUserAvatar
              @user={{user}}
              @avatarSize="tiny"
              @showPresence={{false}}
              @interactive={{false}}
            />
          {{/each}}
        </div>
        {{#if @thread.preview.otherParticipantCount}}
          <div class="chat-thread-participants__other-count">
            {{this.otherCountLabel}}
          </div>
        {{/if}}
      </div>
    {{/if}}
  </template>
}
