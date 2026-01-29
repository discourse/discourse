import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import DMenu from "discourse/float-kit/components/d-menu";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import ChannelData from "./channel-data";
import InlineChannelForm from "./inline-channel-form";
import RuleRow from "./rule-row";

export default class ChannelDetails extends Component {
  @service dialog;
  @service siteSettings;

  @tracked isEditing = false;

  @action
  startEditing() {
    this.isEditing = true;
  }

  @action
  cancelEditing() {
    this.isEditing = false;
  }

  @action
  onChannelSaved() {
    this.isEditing = false;
    this.args.refresh();
  }

  @action
  deleteChannel(channel) {
    this.dialog.deleteConfirm({
      message: i18n("chat_integration.channel_delete_confirm"),
      didConfirm: () => {
        return channel
          .destroyRecord()
          .then(() => this.args.refresh())
          .catch(popupAjaxError);
      },
    });
  }

  <template>
    <div class="admin-config-area-card channel-details">
      <div class="admin-config-area-card__header channel-header">
        <div class="admin-config-area-card__title channel-title">
          {{#if @channel.error_key}}
            <DButton
              @icon="triangle-exclamation"
              @action={{fn @showError @channel}}
              class="btn-danger btn-small channel-error-btn"
            />
          {{/if}}
          {{#if this.isEditing}}
            <InlineChannelForm
              @channel={{@channel}}
              @provider={{@provider}}
              @onSave={{this.onChannelSaved}}
              @onCancel={{this.cancelEditing}}
            />
          {{else}}
            <ChannelData @provider={{@provider}} @channel={{@channel}} />
          {{/if}}
        </div>

        {{#unless this.isEditing}}
          <div class="admin-config-area-card__header-actions">
            <DMenu
              @identifier="channel-actions-{{@channel.id}}"
              @icon="ellipsis-vertical"
              @title={{i18n "chat_integration.channel_actions"}}
              class="btn-default btn-small"
            >
              <:content>
                <DropdownMenu as |dropdown|>
                  <dropdown.item>
                    <DButton
                      @icon="pencil"
                      @label="chat_integration.edit_channel"
                      @action={{this.startEditing}}
                      class="btn-transparent edit-channel"
                    />
                  </dropdown.item>
                  <dropdown.item>
                    <DButton
                      @icon="rocket"
                      @label="chat_integration.test_channel"
                      @action={{fn @test @channel}}
                      class="btn-transparent test-channel"
                    />
                  </dropdown.item>
                  <dropdown.divider />
                  <dropdown.item>
                    <DButton
                      @icon="trash-can"
                      @label="chat_integration.delete_channel"
                      @action={{fn this.deleteChannel @channel}}
                      class="btn-transparent btn-danger delete-channel"
                    />
                  </dropdown.item>
                </DropdownMenu>
              </:content>
            </DMenu>
          </div>
        {{/unless}}
      </div>

      <div class="admin-config-area-card__content channel-body">
        <table class="d-admin-table channel-rules-table">
          <thead>
            <tr>
              <th>{{i18n "chat_integration.rule_table.filter"}}</th>
              <th>{{i18n "chat_integration.rule_table.category"}}</th>
              {{#if this.siteSettings.tagging_enabled}}
                <th>{{i18n "chat_integration.rule_table.tags"}}</th>
              {{/if}}
              <th class="d-admin-row__controls-column"></th>
            </tr>
          </thead>
          <tbody>
            {{#each @channel.rules as |rule|}}
              <RuleRow
                @rule={{rule}}
                @edit={{fn @editRuleWithChannel rule @channel}}
                @refresh={{@refresh}}
              />
            {{/each}}
          </tbody>
        </table>
      </div>

      <div class="admin-config-area-card__footer channel-footer">
        <DButton
          @icon="plus"
          @label="chat_integration.create_rule"
          @action={{fn @createRule @channel}}
          class="btn-default btn-small"
        />
      </div>
    </div>
  </template>
}
