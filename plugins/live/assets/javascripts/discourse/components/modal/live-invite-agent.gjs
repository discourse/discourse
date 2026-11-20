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

export default class LiveInviteAgentModal extends Component {
  @service toasts;

  @tracked agents = [];
  @tracked loading = true;
  @tracked refreshing = false;
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
  async refresh() {
    this.refreshing = true;
    try {
      await this.#loadAgents({ refresh: true });
    } finally {
      this.refreshing = false;
    }
  }

  @action
  async invite(data) {
    try {
      await ajax(`/live/rooms/${this.args.model.room.id}/invite_agent`, {
        type: "POST",
        data: { agent_name: data.agent_name.trim() },
      });
      this.toasts.success({ data: { message: i18n("live.agent.invited") } });
      this.args.closeModal();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  // An empty or unavailable catalogue falls back to the typed name, which is
  // also the only path for agents running outside LiveKit's hosting. Only an
  // explicit refresh surfaces the failure.
  async #loadAgents({ refresh = false } = {}) {
    try {
      const result = await ajax("/live/agents", {
        data: refresh ? { refresh: true } : {},
      });
      this.agents = result.agents ?? [];
    } catch (error) {
      this.agents = [];
      if (refresh) {
        popupAjaxError(error);
      }
    } finally {
      this.loading = false;
    }
  }

  <template>
    <DModal
      class="live-invite-agent-modal"
      @closeModal={{@closeModal}}
      @inline={{@inline}}
      @title={{i18n "live.agent.invite"}}
    >
      <:body>
        <p class="live-invite-agent-modal__hint">
          {{i18n "live.agent.deploy_hint"}}
        </p>
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
                @title={{i18n "live.agent.name"}}
                @type="select"
                @validation="required"
                as |field|
              >
                <div class="live-invite-agent-modal__picker">
                  <field.Control as |select|>
                    {{#each this.agents as |agent|}}
                      <select.Option @value={{agent.name}}>
                        {{agent.name}}
                      </select.Option>
                    {{/each}}
                  </field.Control>
                  <DButton
                    class="btn-flat live-invite-agent-modal__toggle"
                    @action={{this.toggleTyping}}
                    @icon="pencil"
                    @title="live.agent.type_name"
                  />
                  <DButton
                    class="btn-flat live-invite-agent-modal__refresh"
                    @action={{this.refresh}}
                    @icon="arrows-rotate"
                    @isLoading={{this.refreshing}}
                    @title="live.agent.refresh"
                  />
                </div>
              </form.Field>
            {{else}}
              <form.Field
                @format="large"
                @name="agent_name"
                @title={{i18n "live.agent.name"}}
                @type="input"
                @validation="required"
                as |field|
              >
                <div class="live-invite-agent-modal__picker">
                  <field.Control maxlength="256" />
                  {{#if this.agents.length}}
                    <DButton
                      class="btn-flat live-invite-agent-modal__toggle"
                      @action={{this.toggleTyping}}
                      @icon="list"
                      @title="live.agent.pick_name"
                    />
                  {{/if}}
                  <DButton
                    class="btn-flat live-invite-agent-modal__refresh"
                    @action={{this.refresh}}
                    @icon="arrows-rotate"
                    @isLoading={{this.refreshing}}
                    @title="live.agent.refresh"
                  />
                </div>
              </form.Field>
            {{/if}}
            <form.Submit @label="live.agent.invite" />
          </Form>
        </DConditionalLoadingSpinner>
      </:body>
    </DModal>
  </template>
}
