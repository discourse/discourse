import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import LiveInviteAgentModal from "./modal/live-invite-agent.gjs";

export default class LiveInviteAgentButton extends Component {
  @service site;
  @service modal;

  get available() {
    const room = this.args.room;
    const botId = this.site.live_livekit_agent_bot_id;
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
    this.modal.show(LiveInviteAgentModal, { model: { room: this.args.room } });
  }

  <template>
    {{#if this.available}}
      <@item>
        <DButton
          class="btn-transparent live-invite-agent"
          @action={{this.invite}}
          @icon="robot"
          @label="live.agent.invite"
        />
      </@item>
    {{/if}}
  </template>
}
