import Component from "@glimmer/component";
import ChatUserAvatar from "discourse/plugins/chat/discourse/components/chat/user-avatar";
import I18n from "I18n";

export default class ChatThreadParticipants extends Component {
  <template>
    {{#if this.showParticipants}}
      <div class="chat-thread-participants" ...attributes>
        <div class="chat-thread-participants__avatar-group">
          {{#each this.participantsUsers as |user|}}
            <ChatUserAvatar
              @user={{user}}
              @avatarSize="tiny"
              @showPresence={{false}}
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

  get showParticipants() {
    if (this.includeOriginalMessageUser) {
      return this.participantsUsers.length > 1;
    }

    return this.participantsUsers.length > 0;
  }

  get includeOriginalMessageUser() {
    return this.args.includeOriginalMessageUser ?? true;
  }

  get participantsUsers() {
    if (this.includeOriginalMessageUser) {
      return this.args.thread.preview.participantUsers;
    }

    return this.args.thread.preview.participantUsers.filter((user) => {
      return user.id !== this.args.thread.originalMessage.user.id;
    });
  }

  get otherCountLabel() {
    return I18n.t("chat.thread.participants_other_count", {
      count: this.args.thread.preview.otherParticipantCount,
    });
  }
}
