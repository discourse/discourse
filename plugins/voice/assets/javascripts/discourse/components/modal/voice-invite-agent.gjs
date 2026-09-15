import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

export default class VoiceInviteAgentModal extends Component {
  @service toasts;

  @tracked agents = [];
  @tracked loading = true;

  constructor() {
    super(...arguments);
    this.#loadAgents();
  }

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

  // An empty or unavailable catalogue falls back to the typed name, which is
  // also the only path for agents running outside LiveKit's hosting.
  async #loadAgents() {
    try {
      const result = await ajax("/voice/agents");
      this.agents = result.agents ?? [];
    } catch {
      this.agents = [];
    } finally {
      this.loading = false;
    }
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @inline={{@inline}}
      @title={{i18n "voice.agent.invite"}}
    >
      <:body>
        <DConditionalLoadingSpinner @condition={{this.loading}}>
          <Form
            @data={{hash agent_name=""}}
            @onSubmit={{this.invite}}
            as |form|
          >
            {{#if this.agents.length}}
              <form.Field
                @description={{i18n "voice.agent.pick_help"}}
                @name="agent_name"
                @title={{i18n "voice.agent.name"}}
                @type="select"
                @validation="required"
                as |field|
              >
                <field.Control as |select|>
                  {{#each this.agents as |agent|}}
                    <select.Option @value={{agent.name}}>
                      {{agent.name}}
                    </select.Option>
                  {{/each}}
                </field.Control>
              </form.Field>
            {{else}}
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
            {{/if}}
            <form.Submit @label="voice.agent.invite" />
          </Form>
        </DConditionalLoadingSpinner>
      </:body>
    </DModal>
  </template>
}
