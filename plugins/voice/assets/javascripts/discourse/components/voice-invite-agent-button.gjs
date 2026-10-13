import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import VoiceInviteAgentModal from "./modal/voice-invite-agent";

export default class VoiceInviteAgentButton extends Component {
  @service site;
  @service modal;

  get available() {
    const room = this.args.room;
    const botId = this.site.voice_livekit_agent_bot_id;
    const participants = room.active_participants ?? [];
    return (
      botId &&
      room.public &&
      room.expected_transport === "livekit" &&
      participants.some((participant) => participant.id > 0) &&
      !participants.some((participant) => participant.id === botId)
    );
  }

  @action
  invite() {
    this.args.closeMenu?.();
    this.modal.show(VoiceInviteAgentModal, { model: { room: this.args.room } });
  }

  <template>
    {{#if this.available}}
      <@item>
        <DButton
          class="btn-transparent voice-invite-agent"
          @action={{this.invite}}
          @icon="robot"
          @label="voice.agent.invite"
        />
      </@item>
    {{/if}}
  </template>
}
