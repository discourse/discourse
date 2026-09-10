import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import AdminConfigAreaCard from "discourse/admin/components/admin-config-area-card";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import { i18n } from "discourse-i18n";

export default class VoiceAgentIntegrations extends Component {
  @service a11y;
  @service dialog;

  @tracked integrations = [];
  @tracked editing = null;
  @tracked credential = null;

  constructor() {
    super(...arguments);
    this.integrations = this.args.model.integrations;
  }

  @cached
  get formData() {
    return {
      name: this.editing?.name ?? "",
      bot_user_id: this.editing?.bot_user.id ?? "",
      role: this.editing?.role ?? "participant",
      ...Object.fromEntries(
        this.args.model.rooms.map((room) => [
          `room_${room.id}`,
          this.editing?.room_ids.includes(room.id) ?? false,
        ])
      ),
    };
  }

  get roleOptions() {
    return ["participant", "speaker"].map((role) => ({
      id: role,
      name: i18n(`voice.admin.agent_integrations.roles.${role}`),
    }));
  }

  @action
  cancelEdit() {
    this.editing = null;
  }

  @action
  async create(data) {
    const roomIds = this.args.model.rooms
      .filter((room) => data[`room_${room.id}`])
      .map((room) => room.id);

    try {
      const response = await ajax(
        `/admin/plugins/voice/agent-integrations${this.editing ? `/${this.editing.id}` : ""}`,
        {
          type: this.editing ? "PUT" : "POST",
          data: {
            integration: {
              name: data.name,
              bot_user_id: Number(data.bot_user_id),
              room_ids: roomIds,
              role: data.role,
            },
          },
        }
      );
      this.integrations = this.editing
        ? this.integrations.map((integration) =>
            integration.id === this.editing.id
              ? response.integration
              : integration
          )
        : [...this.integrations, response.integration];
      this.editing = null;
      this.credential = response.credential;
      this.a11y.announce(i18n("voice.admin.agent_integrations.saved"));
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  edit(integration) {
    this.editing = integration;
    this.credential = null;
  }

  @action
  async revoke(integration) {
    await this.dialog.deleteConfirm({
      message: i18n("voice.admin.agent_integrations.revoke_confirm", {
        name: integration.name,
      }),
      didConfirm: async () => {
        try {
          await ajax(
            `/admin/plugins/voice/agent-integrations/${integration.id}`,
            {
              type: "DELETE",
            }
          );
          integration.revoked_at = new Date().toISOString();
          this.integrations = [...this.integrations];
        } catch (error) {
          popupAjaxError(error);
        }
      },
    });
  }

  @action
  async restore(integration) {
    try {
      const response = await ajax(
        `/admin/plugins/voice/agent-integrations/${integration.id}/restore`,
        { type: "POST" }
      );
      const index = this.integrations.indexOf(integration);
      this.integrations = this.integrations.with(index, response.integration);
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async rotate(integration) {
    try {
      const response = await ajax(
        `/admin/plugins/voice/agent-integrations/${integration.id}/rotate`,
        { type: "POST" }
      );
      this.credential = response.credential;
      this.a11y.announce(
        i18n("voice.admin.agent_integrations.credential_notice")
      );
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async restoreExclusion(integration, roomId) {
    try {
      await ajax(
        `/admin/plugins/voice/agent-integrations/${integration.id}/exclusions/${roomId}`,
        { type: "DELETE" }
      );
      integration.excluded_room_ids = integration.excluded_room_ids.filter(
        (id) => id !== roomId
      );
      this.integrations = [...this.integrations];
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  roomName(roomId) {
    return (
      this.args.model.rooms.find((room) => room.id === roomId)?.name || roomId
    );
  }

  @action
  roomNames(integration) {
    return integration.room_ids
      .map(
        (id) => this.args.model.rooms.find((room) => room.id === id)?.name || id
      )
      .join(", ");
  }

  <template>
    <section
      class="voice-agent-integrations admin-config-page__main-area"
      ...attributes
    >
      <DPageSubheader
        @titleLabel={{i18n "voice.admin.agent_integrations.title"}}
        @descriptionLabel={{i18n "voice.admin.agent_integrations.description"}}
      />

      <AdminConfigAreaCard
        @heading={{if
          this.editing
          "voice.admin.agent_integrations.edit_title"
          "voice.admin.agent_integrations.create_title"
        }}
      >
        <:content>
          <Form @data={{this.formData}} @onSubmit={{this.create}} as |form|>
            <form.Field
              @name="name"
              @title={{i18n "voice.admin.agent_integrations.name"}}
              @type="input"
              @validation="required|length:1,80"
              as |field|
            >
              <field.Control />
            </form.Field>
            <form.Field
              @name="bot_user_id"
              @title={{i18n "voice.admin.agent_integrations.bot"}}
              @type="select"
              @validation="required"
              @disabled={{this.editing}}
              as |field|
            >
              <field.Control as |control|>
                {{#each @model.bots as |bot|}}
                  <control.Option
                    @value={{bot.id}}
                  >{{bot.username}}</control.Option>
                {{/each}}
              </field.Control>
            </form.Field>
            <form.CheckboxGroup
              @title={{i18n "voice.admin.agent_integrations.rooms"}}
              as |group|
            >
              {{#each @model.rooms as |room|}}
                <group.Field
                  @name={{concat "room_" room.id}}
                  @title={{room.name}}
                  @type="checkbox"
                  as |field|
                >
                  <field.Control />
                </group.Field>
              {{/each}}
            </form.CheckboxGroup>
            <form.Field
              @name="role"
              @title={{i18n "voice.admin.agent_integrations.role"}}
              @type="select"
              as |field|
            >
              <field.Control @includeNone={{false}} as |control|>
                {{#each this.roleOptions as |option|}}
                  <control.Option
                    @value={{option.id}}
                  >{{option.name}}</control.Option>
                {{/each}}
              </field.Control>
            </form.Field>
            <form.Submit @label={{i18n "save"}} />
            {{#if this.editing}}
              <DButton @action={{this.cancelEdit}} @label="cancel" />
            {{/if}}
          </Form>

          {{#if this.credential}}
            <div class="voice-agent-integrations__credential">
              <p>{{i18n "voice.admin.agent_integrations.credential_notice"}}</p>
              <code>{{this.credential}}</code>
            </div>
          {{/if}}
        </:content>
      </AdminConfigAreaCard>

      <AdminConfigAreaCard @heading="voice.admin.agent_integrations.title">
        <:content>
          {{#if this.integrations.length}}
            <table class="d-table">
              <thead class="d-table__header">
                <tr>
                  <th>{{i18n "voice.admin.agent_integrations.name"}}</th>
                  <th>{{i18n "voice.admin.agent_integrations.bot"}}</th>
                  <th>{{i18n "voice.admin.agent_integrations.rooms"}}</th>
                  <th>{{i18n "voice.admin.agent_integrations.role"}}</th>
                  <th></th>
                </tr>
              </thead>
              <tbody class="d-table__body">
                {{#each this.integrations as |integration|}}
                  <tr class="d-table__row">
                    <td class="d-table__cell --overview">
                      <span
                        class="d-table__overview-name"
                      >{{integration.name}}</span>
                    </td>
                    <td class="d-table__cell --detail">
                      <div class="d-table__mobile-label">{{i18n
                          "voice.admin.agent_integrations.bot"
                        }}</div>
                      {{integration.bot_user.username}}
                    </td>
                    <td class="d-table__cell --detail">
                      <div class="d-table__mobile-label">{{i18n
                          "voice.admin.agent_integrations.rooms"
                        }}</div>
                      {{this.roomNames integration}}
                    </td>
                    <td class="d-table__cell --detail">
                      <div class="d-table__mobile-label">{{i18n
                          "voice.admin.agent_integrations.role"
                        }}</div>
                      {{i18n
                        (concat
                          "voice.admin.agent_integrations.roles."
                          integration.role
                        )
                      }}
                    </td>
                    <td class="d-table__cell --controls">
                      <div class="d-table__cell-actions">
                        <DButton
                          class="btn-small"
                          @action={{fn this.edit integration}}
                          @label="edit"
                        />
                        <DButton
                          class="btn-small"
                          @action={{fn this.rotate integration}}
                          @label="voice.admin.agent_integrations.rotate"
                        />
                        {{#if integration.revoked_at}}
                          <DButton
                            class="btn-small"
                            @label="voice.admin.agent_integrations.restore"
                            @action={{fn this.restore integration}}
                          />
                        {{else}}
                          <DButton
                            class="btn-small btn-danger"
                            @label="voice.admin.agent_integrations.revoke"
                            @action={{fn this.revoke integration}}
                          />
                        {{/if}}
                      </div>
                      {{#each integration.excluded_room_ids as |roomId|}}
                        <DButton
                          class="btn-small"
                          @translatedLabel={{i18n
                            "voice.admin.agent_integrations.restore_room"
                            room=(this.roomName roomId)
                          }}
                          @action={{fn
                            this.restoreExclusion
                            integration
                            roomId
                          }}
                        />
                      {{/each}}
                    </td>
                  </tr>
                {{/each}}
              </tbody>
            </table>
          {{else}}
            <p>{{i18n "voice.admin.agent_integrations.empty"}}</p>
          {{/if}}
        </:content>
      </AdminConfigAreaCard>
    </section>
  </template>
}
