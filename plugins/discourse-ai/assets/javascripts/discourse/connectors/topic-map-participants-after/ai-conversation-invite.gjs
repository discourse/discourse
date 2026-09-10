import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Participant from "discourse/components/header/topic/participant";
import AddPmParticipants from "discourse/components/modal/add-pm-participants";
import { or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";

export default class AiConversationInvite extends Component {
  static shouldRender(args) {
    return args.topic.is_bot_pm;
  }

  @service modal;
  @service header;

  get participants() {
    const participants = [
      ...(this.header.topicInfo.details?.allowed_users ?? []),
      ...(this.header.topicInfo.details?.allowed_groups ?? []),
    ];
    return participants;
  }

  @action
  showInvite() {
    this.modal.show(AddPmParticipants, {
      model: {
        title: "discourse_ai.ai_bot.invite_ai_conversation.title",
        inviteModel: this.args.outletArgs.topic,
      },
    });
  }

  <template>
    <div class="ai-conversation__participants">
      <DButton
        class="btn-default ai-conversations__invite-button"
        @action={{this.showInvite}}
        @icon="user-plus"
        @label="discourse_ai.ai_bot.invite_ai_conversation.button"
      />
      {{#each this.participants as |participant|}}
        <Participant
          @avatarSize="medium"
          @type={{if participant.username "user" "group"}}
          @user={{participant}}
          @username={{or participant.username participant.name}}
        />
      {{/each}}
    </div>
  </template>
}
