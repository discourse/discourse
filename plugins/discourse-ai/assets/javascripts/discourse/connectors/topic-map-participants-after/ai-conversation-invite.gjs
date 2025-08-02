import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { or } from "truth-helpers";
import DButton from "discourse/components/d-button";
import Participant from "discourse/components/header/topic/participant";
import AddPmParticipants from "discourse/components/modal/add-pm-participants";

export default class AiConversationInvite extends Component {
  static shouldRender(args) {
    return args.topic.is_bot_pm;
  }

  @service site;
  @service modal;
  @service header;
  @service sidebarState;

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
        @icon="user-plus"
        @label="discourse_ai.ai_bot.invite_ai_conversation.button"
        @action={{this.showInvite}}
        class="btn-default ai-conversations__invite-button"
      />
      {{#each this.participants as |participant|}}
        <Participant
          @user={{participant}}
          @type={{if participant.username "user" "group"}}
          @username={{or participant.username participant.name}}
          @avatarSize="medium"
        />
      {{/each}}
    </div>
  </template>
}
