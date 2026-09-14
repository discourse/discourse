import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

export default class VoiceInviteAgentModal extends Component {
  @service toasts;

  @action
  async invite(data) {
    try {
      await ajax(`/voice/rooms/${this.args.model.room.id}/invite_agent`, {
        type: "POST",
        data: { agent_name: data.agent_name.trim() },
      });
      this.toasts.success({ data: { message: i18n("voice.agent.invited") } });
      this.args.closeModal();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @inline={{@inline}}
      @title={{i18n "voice.agent.invite"}}
    >
      <:body>
        <Form @data={{hash agent_name=""}} @onSubmit={{this.invite}} as |form|>
          <form.Field
            @description={{i18n "voice.agent.name_help"}}
            @name="agent_name"
            @title={{i18n "voice.agent.name"}}
            @type="input"
            @validation="required"
            as |field|
          >
            <field.Control maxlength="256" />
          </form.Field>
          <form.Submit @label="voice.agent.invite" />
        </Form>
      </:body>
    </DModal>
  </template>
}
