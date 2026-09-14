import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DMenu from "discourse/float-kit/components/d-menu";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
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
              class="btn-danger btn-small channel-error-btn"
              @action={{fn @showError @channel}}
              @icon="triangle-exclamation"
            />
          {{/if}}
          {{#if this.isEditing}}
            <InlineChannelForm
              @channel={{@channel}}
              @onCancel={{this.cancelEditing}}
              @onSave={{this.onChannelSaved}}
              @provider={{@provider}}
            />
          {{else}}
            <ChannelData @channel={{@channel}} @provider={{@provider}} />
          {{/if}}
        </div>

        {{#unless this.isEditing}}
          <div class="admin-config-area-card__header-actions">
            <DMenu
              class="btn-default btn-small"
              @icon="ellipsis-vertical"
              @identifier="channel-actions-{{@channel.id}}"
              @title={{i18n "chat_integration.channel_actions"}}
            >
              <:content>
                <DDropdownMenu as |dropdown|>
                  <dropdown.item>
                    <DButton
                      class="btn-transparent edit-channel"
                      @action={{this.startEditing}}
                      @icon="pencil"
                      @label="chat_integration.edit_channel"
                    />
                  </dropdown.item>
                  <dropdown.item>
                    <DButton
                      class="btn-transparent test-channel"
                      @action={{fn @test @channel}}
                      @icon="rocket"
                      @label="chat_integration.test_channel"
                    />
                  </dropdown.item>
                  <dropdown.divider />
                  <dropdown.item>
                    <DButton
                      class="btn-transparent btn-danger delete-channel"
                      @action={{fn this.deleteChannel @channel}}
                      @icon="trash-can"
                      @label="chat_integration.delete_channel"
                    />
                  </dropdown.item>
                </DDropdownMenu>
              </:content>
            </DMenu>
          </div>
        {{/unless}}
      </div>

      <div class="admin-config-area-card__content channel-body">
        <table class="d-table channel-rules-table">
          <thead class="d-table__header">
            <tr>
              <th>{{i18n "chat_integration.rule_table.filter"}}</th>
              <th>{{i18n "chat_integration.rule_table.category"}}</th>
              {{#if this.siteSettings.tagging_enabled}}
                <th>{{i18n "chat_integration.rule_table.tags"}}</th>
              {{/if}}
              <th></th>
            </tr>
          </thead>
          <tbody>
            {{#each @channel.rules as |rule|}}
              <RuleRow
                @edit={{fn @editRuleWithChannel rule @channel}}
                @refresh={{@refresh}}
                @rule={{rule}}
              />
            {{/each}}
          </tbody>
        </table>
      </div>

      <div class="admin-config-area-card__footer channel-footer">
        <DButton
          class="btn-default btn-small"
          @action={{fn @createRule @channel}}
          @icon="plus"
          @label="chat_integration.create_rule"
        />
      </div>
    </div>
  </template>
}
