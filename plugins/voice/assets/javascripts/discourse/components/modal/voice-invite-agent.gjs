import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

export default class VoiceInviteAgentModal extends Component {
  @service toasts;

  @tracked agents = [];
  @tracked loading = true;
  @tracked typing = false;

  constructor() {
    super(...arguments);
    this.#loadAgents();
  }

  get showPicker() {
    return this.agents.length > 0 && !this.typing;
  }

  @action
  toggleTyping() {
    this.typing = !this.typing;
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
      class="voice-invite-agent-modal"
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
            {{#if this.showPicker}}
              <form.Field
                @format="large"
                @name="agent_name"
                @title={{i18n "voice.agent.name"}}
                @type="select"
                @validation="required"
                as |field|
              >
                <div class="voice-invite-agent-modal__picker">
                  <field.Control as |select|>
                    {{#each this.agents as |agent|}}
                      <select.Option @value={{agent.name}}>
                        {{agent.name}}
                      </select.Option>
                    {{/each}}
                  </field.Control>
                  <DButton
                    class="btn-flat voice-invite-agent-modal__toggle"
                    @action={{this.toggleTyping}}
                    @icon="pencil"
                    @title="voice.agent.type_name"
                  />
                </div>
              </form.Field>
            {{else}}
              <form.Field
                @description={{i18n "voice.agent.name_help"}}
                @format="large"
                @name="agent_name"
                @title={{i18n "voice.agent.name"}}
                @type="input"
                @validation="required"
                as |field|
              >
                {{#if this.agents.length}}
                  <div class="voice-invite-agent-modal__picker">
                    <field.Control maxlength="256" />
                    <DButton
                      class="btn-flat voice-invite-agent-modal__toggle"
                      @action={{this.toggleTyping}}
                      @icon="list"
                      @title="voice.agent.pick_name"
                    />
                  </div>
                {{else}}
                  <field.Control maxlength="256" />
                {{/if}}
              </form.Field>
            {{/if}}
            <form.Submit @label="voice.agent.invite" />
          </Form>
        </DConditionalLoadingSpinner>
      </:body>
    </DModal>
  </template>
}
